require "shellwords"
require "taglib"
require "tempfile"

module Muzak
  module Plugin
    class Feh < StubPlugin
      DEFAULT_FEH_ARGS = [
        "feh",
        "--auto-zoom",
      ]

      def initialize
        super
        @feh_args = DEFAULT_FEH_ARGS + Shellwords.split(Config.plugin_feh["feh_args"])

        if Config.art_geometry
          @feh_args << "--geometry"
          @feh_args << Config.art_geometry
        end

        @pid = nil
      end

      def song_loaded(song)
        art_path = song.best_guess_album_art

        art_path = tmp_art_from_tags(song) unless art_path

        feh art_path
      end

      def song_unloaded
        stop_feh! if feh_running?
      end

      def player_deactivated
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

      def tmp_art_from_tags(song)
        art_data = case File.extname(song.path).downcase
                   when ".mp3"
                     TagLib::MPEG::File.open(song.path) do |file|
                       tag = file.id3v2_tag
                       break unless tag

                        cover = tag.frame_list("APIC").first
                        break unless cover
                        cover.picture
                      end
                    when ".flac"
                      TagLib::FLAC::File.open(song.path) do |file|
                        picture = file.picture_list.find do |pic|
                          pic.type == TagLib::FLAC::Picture::FrontCover
                        end

                        break unless picture
                        pic.data
                      end
                   end

        return unless art_data

        file = Tempfile.new
        file.write(art_data)
        file.path
      end
    end
  end
end
