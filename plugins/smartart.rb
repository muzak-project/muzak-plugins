require "glyr"

module Muzak
  module Plugin
    class SmartArt < StubPlugin
      DEFAULT_FEH_ARGS = [
        "feh",
        "--auto-zoom",
      ]

      def self.available?
        Utils.which?("feh")
      end

      def initialize
        super
        @feh_args = DEFAULT_FEH_ARGS + Config.plugin_smartart["feh_args"]

        if Config.art_geometry
          @feh_args << "--geometry"
          @feh_args << Config.art_geometry
        end

        @pid = nil
      end

      def song_loaded(song)
        if song.best_guess_album_art
          feh song.best_guess_album_art
        else
          debug "no local art found for '#{song.title}', querying glyr"
          query = Glyr.query(artist: song.artist, album: song.album)
          img_url = query&.cover_art&.first&.url rescue nil
          feh img_url
        end
      end

      def song_unloaded
        stop_feh! if feh_running?
      end

      def player_deactivated
        stop_feh! if feh_running?
      end

      def instance_quitting
        stop_feh! if feh_running?
      end

      private

      def feh_running?
        begin
          !!@pid && Process.waitpid(@pid, Process::WNOHANG).nil?
        rescue Errno::ECHILD
          false
        end
      end

      def start_feh!(path)
        args = [*@feh_args, path]
        @pid = Process.spawn(*args)
      end

      def stop_feh!
        Process.kill :TERM, @pid
        Process.wait @pid
        @pid = nil
      end

      def feh(art_path)
        # don't let old artwork linger.
        stop_feh! if feh_running?

        start_feh! art_path if art_path
      end
    end
  end
end
