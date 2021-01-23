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

    alias_method :init, :sv_init
    alias_method :deinit, :sv_deinit
    alias_method :open_slot, :sv_open_slot
    alias_method :lock_slot, :sv_lock_slot
    alias_method :unlock_slot, :sv_unlock_slot
    alias_method :close_slot, :sv_close_slot
    alias_method :new_module, :sv_new_module
    alias_method :connect_module, :sv_connect_module
    alias_method :send_event, :sv_send_event
  end
end

extend Supersonic::DLL

def play_me
  version = init nil, 44100, 2, 0
  p "version: #{version}"

  open_slot 0

  lock_slot 0
  mod_num = new_module 0, "Generator", "Generator", 0, 0, 0
  unlock_slot 0

  if mod_num >= 0
    p "module number: #{mod_num}"

    lock_slot 0
    connect_module 0, mod_num, 0
    unlock_slot 0

    send_event 0, 0, 64, 128, mod_num + 1, 0, 0
    sleep 1
    # 128 = NOTE_OFF in third argument
    send_event 0, 0, 128, 0, 0, 0, 0
  end

  close_slot 0
  deinit
end

