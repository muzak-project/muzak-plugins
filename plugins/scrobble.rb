require "net/http"
require "digest"

module Muzak
  module Plugin
    class Scrobble < StubPlugin
      include Utils

      def initialize
        super
        @username = Config.plugin_scrobble["username"]
        @password_hash = Config.plugin_scrobble["password_hash"]
        @polling = Config.plugin_scrobble["polling"]
      end

      def instance_started(instance)
        return unless @polling
        @running = true
        Thread.new { poll_now_playing instance }
      end

      def instance_quitting
        return unless @polling
        @running = false
      end

      def song_loaded(song)
        # this should never happen, but guard against it just in case
        # the user is dumb and enabled polling when their player supports
        # events
        return if @polling

        scrobble song
      end

      private

      def poll_now_playing(instance)
        cache_np = nil

        while @running do
          if instance.player.now_playing != cache_np
            cache_np = instance.player.now_playing
            scrobble cache_np
          end

          sleep 1
        end
      end

      def scrobble(song)
        if @username.nil? || @password_hash.nil?
          error "missing username or password"
          return
        end

        if song.title.nil? || song.artist.nil?
          debug "refusing to scrobble '#{song.path}' without metadata"
          return
        end

        begin
          handshake_endpoint = "http://post.audioscrobbler.com/"
          handshake_params = {
            "hs" => true,
            "p" => 1.1,
            "c" => "lsd",
            "v" => "1.0.4",
            "u" => @username
          }

          uri = URI(handshake_endpoint)
          uri.query = URI.encode_www_form(handshake_params)

          resp = Net::HTTP.get_response(uri)

          status, token, post_url, int = resp.body.split("\n")

          unless status =~ /UP(TO)?DATE/
            error "bad handshake, got '#{status}'"
            return
          end

          session_token = Digest::MD5.hexdigest(@password_hash + token)

          request_params = {
            "u" => @username,
            "s" => session_token,
            "a[0]" => song.artist,
            "t[0]" => song.title,
            "b[0]" => song.album,
            "m[0]" => "", # we don't know the MBID, so send an empty one
            "l[0]" => song.length,
            "i[0]" => Time.now.gmtime.strftime("%Y-%m-%d %H:%M:%S")
          }

          uri = URI(URI.encode(post_url))

          resp = Net::HTTP.post_form(uri, request_params)

          status, int = resp.body.split("\n")

          case status
          when "OK"
            debug "scrobble of '#{song.title}' successful"
          else
            debug "scrobble of '#{song.title}' failed, got '#{status}'"
          end
        rescue Exception => e
          error "something exploded, got #{e.to_s}"
        end
      end
    end
  end
end
