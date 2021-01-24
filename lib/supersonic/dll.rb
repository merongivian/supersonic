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
      attach_function :sv_find_module, [ :int, :string ], :int
      attach_function :sv_send_event, [ :int, :int, :int, :int, :int, :int, :int ], :int
    end

    class Slot
      include Supersonic::Sunvox::DLL

      def initialize(slot_number, &block)
        @slot_number = slot_number
        open(&block)
      end

      def new_module(*args)
        lock { sv_new_module @slot_number, *args }
      end

      def load_module(filename, *args, &block)
        path = File.expand_path(__dir__ << "/../../ext")

        File.open("#{path}/#{filename}") do |f|
          module_number = lock { sv_load_module_from_memory @slot_number, f.read, f.size, *args }
          block.call(module_number)
        end
      end

      def connect_module(*args)
        lock { sv_connect_module @slot_number, *args }
      end

      def find_module(module_name)
        sv_find_module @slot_number, module_name
      end

      def send_event(*args)
        sv_send_event @slot_number, *args
      end

      private

      def open(&block)
        sv_open_slot @slot_number
        block.call self
        sv_close_slot @slot_number
      end

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
      mod_num = new_module "Generator", "Generator", 0, 0, 0

      if mod_num >= 0
        connect_module mod_num, 0

        send_event 0, 64, 128, mod_num + 1, 0, 0

        sleep 1
        # 128 = NOTE_OFF in second argument
        send_event 0, 128, 0, 0, 0, 0
      end

      sleep 1
      load_module('organ.sunsynth', 0, 0, 0) do |mod_num2|
        if mod_num2 >= 0
          connect_module mod_num2, 0

          send_event 0, 64, 128, mod_num2 + 1, 0, 0

          sleep 1
          # 128 = NOTE_OFF in second argument
          send_event 0, 128, 0, 0, 0, 0
        end
      end

      sleep 1

      mod_num3 = find_module "SpectraVoice"

      p "module number #{mod_num3}"
      if mod_num3 >= 0
        send_event 0, 64, 128, mod_num3 + 1, 0, 0

        sleep 1
        # 128 = NOTE_OFF in second argument
        send_event 0, 128, 0, 0, 0, 0
      end
    end
  end
end
