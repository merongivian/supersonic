require 'ffi'

module Supersonic
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
    attach_function :sv_connect_module, [ :int, :int, :int ], :int
    attach_function :sv_send_event, [ :int, :int, :int, :int, :int, :int, :int ], :int
  end
end

extend Supersonic::DLL

def play_me
  version = sv_init nil, 44100, 2, 0
  p "version: #{version}"

  sv_open_slot 0

  sv_lock_slot 0
  mod_num = sv_new_module 0, "Generator", "Generator", 0, 0, 0
  sv_unlock_slot 0

  if mod_num >= 0
    p "module number: #{mod_num}"

    sv_lock_slot 0
    sv_connect_module 0, mod_num, 0
    sv_unlock_slot 0

    sv_send_event 0, 0, 64, 128, mod_num + 1, 0, 0
    sleep 1
    # 128 = NOTE_OFF in third argument
    sv_send_event 0, 0, 128, 0, 0, 0, 0
  end

  sv_close_slot 0
  sv_deinit
end

