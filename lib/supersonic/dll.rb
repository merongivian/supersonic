require 'ffi'

module Supersonic
  module Sunvox
    module DLL
      lib_path = File.expand_path(__dir__ << "/../../ext")

      extend FFI::Library

      ffi_lib ["#{lib_path}/sunvox.dylib"]

      attach_function :sv_init, [ :string, :int, :int, :uint32 ], :int
      attach_function :sv_deinit, [], :int
      attach_function :sv_open_slot, [ :int ], :int
      attach_function :sv_lock_slot, [ :int ], :int
      attach_function :sv_unlock_slot, [ :int ], :int
      attach_function :sv_close_slot, [ :int ], :int
      attach_function :sv_new_module, [ :int, :string, :string, :int, :int, :int ], :int
      attach_function :sv_load_module_from_memory, [ :int, :pointer, :uint32_t, :int, :int, :int ], :int
      attach_function :sv_connect_module, [ :int, :int, :int ], :int
      attach_function :sv_get_number_of_module_ctls, [ :int, :int ], :int
      attach_function :sv_get_module_ctl_name, [ :int, :int, :int ], :string
      attach_function :sv_get_module_ctl_value, [ :int, :int, :int, :int ], :int
      attach_function :sv_connect_module, [ :int, :int, :int ], :int
      attach_function :sv_disconnect_module, [ :int, :int, :int ], :int
      attach_function :sv_find_module, [ :int, :string ], :int
      attach_function :sv_send_event, [ :int, :int, :int, :int, :int, :int, :int ], :int
    end

    class Slot
      include Supersonic::Sunvox::DLL

      def initialize(slot_number, &block)
        @slot_number = slot_number
        open(&block)
      end

      def with_module(**opts, &block)
        set_module.tap do |the_module|
          the_module.instance_eval(&block)
        end
      end

      def set_module(**opts)
        Module.new(slot_number: @slot_number, **opts)
      end

      def chain(*modules)
        last_module_connected = modules.first

        modules.map do |the_module|
          last_module_connected.connect(the_module)
          last_module_connected = the_module
        end

        modules.last.connect
      end

      private

      def open(&block)
        sv_open_slot @slot_number
        block.call self
        sv_close_slot @slot_number
      end
    end

    class Module
      include Supersonic::Sunvox::DLL

      def initialize(name: nil, filepath: nil, slot_number: , type: nil, x: 0, y: 0, z: 0)
        @slot_number = slot_number

        @module_number =
          if name && type
            lock { sv_new_module @slot_number, type, name, x, y, z }
          elsif name
            sv_find_module @slot_number, name
          elsif filepath
            File.open(filepath) do |f|
              lock do
                sv_load_module_from_memory(
                  @slot_number, f.read, f.size, x, y, z
                )
              end
            end
          else
            p 'bad arguments, couldnt process module creation'
          end
      end

      def ctl_count
        @ctl_count ||= sv_get_number_of_module_ctls @slot_number, @module_number
      end

      def ctl_name(ctl_num)
        sv_get_module_ctl_name @slot_number, @module_number, ctl_num
      end

      def ctl_num(ctl_name)
        all_ctl_names.index(ctl_name) + 1
      end

      def all_ctl_names
        @all_ctl_names ||= (1..ctl_count).map(&method(:ctl_name))
      end

      def get_ctl_value(ctl_num, scale: 0)
        sv_get_module_ctl_value @slot_number, @module_number, ctl_num, scale
      end

      def connect(destination = 0)
        lock do
          sv_connect_module @slot_number, @module_number, destination.to_i
        end
      end

      def disconnect(destination = 0)
        lock do
          sv_disconnect_module @slot_number, @module_number, destination.to_i
        end
      end

      def send_event(track_num: , note: , vel: , ctl: 0, ctl_value: 0)
        controller_num = ctl.is_a?(String) ? ctl_num(ctl) : ctl

        sv_send_event(
          @slot_number,
          track_num,
          note,
          vel,
          @module_number + 1,
          controller_num,
          ctl_value
        )
      end

      def to_i
        @module_number
      end

      private

      def lock(&block)
        sv_lock_slot @slot_number
        block_return_value = block.call
        sv_unlock_slot @slot_number
        block_return_value
      end
    end

    module DSL
      include Supersonic::Sunvox::DLL

      def with_sunvox_init(&block)
        version = sv_init nil, 44100, 2, 0
        p "version: #{version}"
        block.call
        sv_deinit
      end

      def with_slot(slot_number, &block)
        Supersonic::Sunvox::Slot.new(slot_number) do |slot|
          slot.instance_eval(&block)
        end
      end
    end
  end
end

extend Supersonic::Sunvox::DSL

def play_me
  with_sunvox_init do
    with_slot 0 do
      #with_module(name: 'beep', type: 'Generator') do
        #connect
        #send_event(track_num: 0, note: 64, vel: 128)
        #sleep 1
        #send_event(track_num: 0, note: 128, vel: 0)
      #end

      #sleep 1

      #with_module(name: 'beep') do
        #send_event(track_num: 0, note: 60, vel: 128, ctl: 'Waveform', ctl_value: 25)
        #sleep 1
        #send_event(track_num: 0, note: 128, vel: 0)
      #end

      #sleep 1

      #filepath = File.expand_path(__dir__ << "/../../ext") << "/organ.sunsynth"

      #with_module(filepath: filepath) do
        #connect
        #send_event(track_num: 0, note: 60, vel: 128)
        #sleep 1
        #send_event(track_num: 0, note: 128, vel: 0)
      #end

      generator = set_module(name: 'beep2', type: 'Analog generator')
      flanger = set_module(name: 'flanger', type: 'Flanger')
      reverb = set_module(name: 'reverb', type: 'Reverb')

      chain(generator, reverb, flanger)
      #generator.connect(reverb)
      #reverb.connect(flanger)
      #flanger.connect

      generator.send_event(track_num: 0, note: 60, vel: 128)
      reverb.send_event(track_num: 0, note: 0, vel: 0, ctl: 3, ctl_value: 100)
      sleep 1
      generator.send_event(track_num: 0, note: 128, vel: 0)
      sleep 1
      generator.send_event(track_num: 0, note: 64, vel: 128)
      flanger.send_event(track_num: 0, note: 0, vel: 0, ctl: 2, ctl_value: 500)
      sleep 3
      generator.send_event(track_num: 0, note: 128, vel: 0)
    end
  end
end
