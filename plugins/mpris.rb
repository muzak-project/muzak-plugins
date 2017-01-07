require "dbus"

module Muzak
  module Plugin
    class MPRIS < StubPlugin
      def instance_started(instance)
        start_dbus_service! instance
      end

      private

      class MPRISImpl < DBus::Object
        attr_accessor :instance

        def initialize(path, instance)
          super path
          @instance = instance
        end

        dbus_interface "org.mpris.MediaPlayer2" do
          dbus_method :Raise do
            # nothing.
          end

          dbus_method :Quit do
            # nothing.
          end
        end

        dbus_interface "org.mpris.MediaPlayer2.Player" do
          dbus_method :Next do
            instance.next
          end

          dbus_method :Previous do
            instance.previous
          end

          dbus_method :Pause do
            instance.pause
          end

          dbus_method :PlayPause do
            instance.toggle
          end

          dbus_method :Stop do
            instance.player.deactivate!
          end

          dbus_method :Play do
            instance.play
          end

          dbus_method :Seek, "in Offset:x" do |offset|
            # nothing.
          end

          dbus_method :SetPosition, "in TrackId:o, in Position:x" do |id, pos|
            # nothing.
          end

          dbus_method :OpenUri, "in Uri:s" do |uri|
            # nothing.
          end
        end
      end

      def start_dbus_service!(instance)
        bus = DBus.session_bus
        begin
          service = bus.request_service "org.mpris.MediaPlayer2.muzak"
          mpris = MPRISImpl.new("/org/mpris/MediaPlayer2", instance)
          service.export(mpris)

          event_loop = DBus::Main.new
          event_loop << bus
          event_loop.run
        rescue DBus::NameRequestError
          error "!!!"
        end
      end
    end
  end
end
