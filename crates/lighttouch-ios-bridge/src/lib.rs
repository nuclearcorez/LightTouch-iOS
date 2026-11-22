//! Small C ABI surface for the Swift/UIKit frontend. The engine remains owned by LightTouch core.
use lighttouch_core::{
    library::{Library, Record},
    runtime::{BootOptions, Contact, Device, Runtime, State},
    sys,
};
use std::{
    ffi::{CStr, CString, c_char},
    path::PathBuf,
    ptr,
    slice,
    sync::Mutex,
};

pub struct LtIosContext {
    library: Mutex<Library>,
    runtime: Mutex<Option<Runtime>>,
}

#[repr(C)]
pub struct LtIosStatus {
    pub state: u32,
    pub guest_shutdown_confirmed: u32,
    pub storage_failed: u32,
    pub dirty: u32,
    pub engine_exit: i32,
    pub frames: u64,
}

#[repr(C)]
pub struct LtIosFrameInfo {
    pub width: u32,
    pub height: u32,
    pub stride: u32,
    pub sequence: u64,
    pub timestamp_ns: u64,
    pub bytes: u64,
}

fn error_code(error: &lighttouch_core::Error) -> i32 {
    error.status
}

unsafe fn input<'a>(value: *const c_char) -> Result<&'a str, i32> {
    if value.is_null() {
        return Err(sys::LT_INVALID);
    }
    unsafe { CStr::from_ptr(value) }.to_str().map_err(|_| sys::LT_INVALID)
}

unsafe fn write_error(buffer: *mut c_char, capacity: usize, message: &str) {
    if buffer.is_null() || capacity == 0 {
        return;
    }
    let bytes = message.as_bytes();
    let count = bytes.len().min(capacity - 1);
    unsafe {
        ptr::copy_nonoverlapping(bytes.as_ptr(), buffer.cast::<u8>(), count);
        *buffer.add(count) = 0;
    }
}

#[unsafe(no_mangle)]
pub unsafe extern "C" fn lt_ios_context_open(
    root: *const c_char,
    out_context: *mut *mut LtIosContext,
    error_buffer: *mut c_char,
    error_capacity: usize,
) -> i32 {
    if out_context.is_null() {
        unsafe { write_error(error_buffer, error_capacity, "out_context is null") };
        return sys::LT_INVALID;
    }
    let root = match unsafe { input(root) } {
        Ok(v) => PathBuf::from(v),
        Err(code) => {
            unsafe { write_error(error_buffer, error_capacity, "invalid data-root path") };
            return code;
        }
    };
    match Library::open(&root) {
        Ok(library) => {
            let context = Box::new(LtIosContext {
                library: Mutex::new(library),
                runtime: Mutex::new(None),
            });
            unsafe { *out_context = Box::into_raw(context) };
            sys::LT_OK
        }
        Err(error) => {
            unsafe { write_error(error_buffer, error_capacity, &error.to_string()) };
            error_code(&error)
        }
    }
}

#[unsafe(no_mangle)]
pub unsafe extern "C" fn lt_ios_records_json(
    context: *mut LtIosContext,
    out_json: *mut *mut c_char,
    error_buffer: *mut c_char,
    error_capacity: usize,
) -> i32 {
    if context.is_null() || out_json.is_null() {
        unsafe { write_error(error_buffer, error_capacity, "invalid context or output pointer") };
        return sys::LT_INVALID;
    }
    let context = unsafe { &*context };
    let library = match context.library.lock() {
        Ok(v) => v,
        Err(_) => {
            unsafe { write_error(error_buffer, error_capacity, "library lock poisoned") };
            return sys::LT_BUSY;
        }
    };
    match library.records().and_then(|records: Vec<Record>| {
        serde_json::to_string(&records).map_err(|e| lighttouch_core::Error::invalid(e.to_string()))
    }) {
        Ok(json) => match CString::new(json) {
            Ok(json) => {
                unsafe { *out_json = json.into_raw() };
                sys::LT_OK
            }
            Err(_) => {
                unsafe { write_error(error_buffer, error_capacity, "record JSON contains a NUL byte") };
                sys::LT_ENGINE
            }
        },
        Err(error) => {
            unsafe { write_error(error_buffer, error_capacity, &error.to_string()) };
            error_code(&error)
        }
    }
}

#[unsafe(no_mangle)]
pub unsafe extern "C" fn lt_ios_start(
    context: *mut LtIosContext,
    record_id: *const c_char,
    engine_path: *const c_char,
    recover_dirty: u32,
    error_buffer: *mut c_char,
    error_capacity: usize,
) -> i32 {
    if context.is_null() {
        unsafe { write_error(error_buffer, error_capacity, "context is null") };
        return sys::LT_INVALID;
    }
    let record_id = match unsafe { input(record_id) } {
        Ok(v) => v,
        Err(code) => {
            unsafe { write_error(error_buffer, error_capacity, "invalid record id") };
            return code;
        }
    };
    let engine_path = match unsafe { input(engine_path) } {
        Ok(v) => PathBuf::from(v),
        Err(code) => {
            unsafe { write_error(error_buffer, error_capacity, "invalid engine path") };
            return code;
        }
    };
    let context = unsafe { &*context };
    let mut runtime_slot = match context.runtime.lock() {
        Ok(v) => v,
        Err(_) => {
            unsafe { write_error(error_buffer, error_capacity, "runtime lock poisoned") };
            return sys::LT_BUSY;
        }
    };
    if runtime_slot.is_some() {
        unsafe { write_error(error_buffer, error_capacity, "a guest session already exists") };
        return sys::LT_BUSY;
    }
    let library = match context.library.lock() {
        Ok(v) => v,
        Err(_) => {
            unsafe { write_error(error_buffer, error_capacity, "library lock poisoned") };
            return sys::LT_BUSY;
        }
    };
    let mut progress = |_done: u64, _total: u64| true;
    let device = match Device::open(&library, record_id, recover_dirty != 0, &mut progress) {
        Ok(v) => v,
        Err(error) => {
            unsafe { write_error(error_buffer, error_capacity, &error.to_string()) };
            return error_code(&error);
        }
    };
    drop(library);
    let options = BootOptions {
        engine: engine_path,
        bootrom: None,
        guest_package: None,
        serial_log: None,
        audio: false,
        headphones: false,
        network: None,
    };
    let runtime = match Runtime::create(device, &options) {
        Ok(v) => v,
        Err(error) => {
            unsafe { write_error(error_buffer, error_capacity, &error.to_string()) };
            return error_code(&error);
        }
    };
    *runtime_slot = Some(runtime);
    match runtime_slot.as_ref().expect("runtime was just stored").start() {
        Ok(()) => sys::LT_OK,
        Err(error) => {
            unsafe { write_error(error_buffer, error_capacity, &error.to_string()) };
            error_code(&error)
        }
    }
}

#[unsafe(no_mangle)]
pub unsafe extern "C" fn lt_ios_poll(
    context: *mut LtIosContext,
    out_status: *mut LtIosStatus,
    error_buffer: *mut c_char,
    error_capacity: usize,
) -> i32 {
    if context.is_null() || out_status.is_null() {
        unsafe { write_error(error_buffer, error_capacity, "invalid context or status pointer") };
        return sys::LT_INVALID;
    }
    let context = unsafe { &*context };
    let slot = match context.runtime.lock() {
        Ok(v) => v,
        Err(_) => {
            unsafe { write_error(error_buffer, error_capacity, "runtime lock poisoned") };
            return sys::LT_BUSY;
        }
    };
    let Some(runtime) = slot.as_ref() else {
        unsafe { write_error(error_buffer, error_capacity, "no guest session") };
        return sys::LT_INVALID;
    };
    match runtime.poll() {
        Ok(status) => {
            let state = match status.state {
                State::Stopped => 0,
                State::Starting => 1,
                State::Running => 2,
                State::Paused => 3,
                State::Stopping => 4,
                State::Failed => 5,
            };
            unsafe {
                *out_status = LtIosStatus {
                    state,
                    guest_shutdown_confirmed: status.guest_shutdown_confirmed as u32,
                    storage_failed: status.storage_failed as u32,
                    dirty: status.dirty as u32,
                    engine_exit: status.engine_exit,
                    frames: status.frames,
                };
            }
            sys::LT_OK
        }
        Err(error) => {
            unsafe { write_error(error_buffer, error_capacity, &error.to_string()) };
            error_code(&error)
        }
    }
}

#[unsafe(no_mangle)]
pub unsafe extern "C" fn lt_ios_copy_frame(
    context: *mut LtIosContext,
    pixels: *mut u8,
    capacity: usize,
    since_sequence: *mut u64,
    out_info: *mut LtIosFrameInfo,
    error_buffer: *mut c_char,
    error_capacity: usize,
) -> i32 {
    if context.is_null() || pixels.is_null() || since_sequence.is_null() || out_info.is_null() {
        unsafe { write_error(error_buffer, error_capacity, "invalid frame buffer or output pointer") };
        return sys::LT_INVALID;
    }
    let context = unsafe { &*context };
    let slot = match context.runtime.lock() {
        Ok(v) => v,
        Err(_) => {
            unsafe { write_error(error_buffer, error_capacity, "runtime lock poisoned") };
            return sys::LT_BUSY;
        }
    };
    let Some(runtime) = slot.as_ref() else {
        unsafe { write_error(error_buffer, error_capacity, "no guest session") };
        return sys::LT_INVALID;
    };
    let buffer = unsafe { slice::from_raw_parts_mut(pixels, capacity) };
    let sequence = unsafe { &mut *since_sequence };
    match runtime.copy_frame(buffer, sequence) {
        Ok(Some(info)) => {
            unsafe {
                *out_info = LtIosFrameInfo {
                    width: info.width,
                    height: info.height,
                    stride: info.stride,
                    sequence: info.sequence,
                    timestamp_ns: info.timestamp_ns,
                    bytes: info.bytes,
                };
            }
            sys::LT_OK
        }
        Ok(None) => sys::LT_AGAIN,
        Err(error) => {
            unsafe { write_error(error_buffer, error_capacity, &error.to_string()) };
            error_code(&error)
        }
    }
}

#[unsafe(no_mangle)]
pub unsafe extern "C" fn lt_ios_touch(
    context: *mut LtIosContext,
    timestamp_ns: u64,
    contact_id: u32,
    phase: u32,
    x: f64,
    y: f64,
    error_buffer: *mut c_char,
    error_capacity: usize,
) -> i32 {
    if context.is_null() {
        unsafe { write_error(error_buffer, error_capacity, "context is null") };
        return sys::LT_INVALID;
    }
    let context = unsafe { &*context };
    let slot = match context.runtime.lock() {
        Ok(v) => v,
        Err(_) => {
            unsafe { write_error(error_buffer, error_capacity, "runtime lock poisoned") };
            return sys::LT_BUSY;
        }
    };
    let Some(runtime) = slot.as_ref() else {
        unsafe { write_error(error_buffer, error_capacity, "no guest session") };
        return sys::LT_INVALID;
    };
    match runtime.touch(timestamp_ns, &[Contact { id: contact_id, phase, x, y }]) {
        Ok(()) => sys::LT_OK,
        Err(error) => {
            unsafe { write_error(error_buffer, error_capacity, &error.to_string()) };
            error_code(&error)
        }
    }
}

#[unsafe(no_mangle)]
pub unsafe extern "C" fn lt_ios_button(
    context: *mut LtIosContext,
    button: u32,
    down: u32,
    error_buffer: *mut c_char,
    error_capacity: usize,
) -> i32 {
    if context.is_null() {
        unsafe { write_error(error_buffer, error_capacity, "context is null") };
        return sys::LT_INVALID;
    }
    let context = unsafe { &*context };
    let slot = match context.runtime.lock() {
        Ok(v) => v,
        Err(_) => {
            unsafe { write_error(error_buffer, error_capacity, "runtime lock poisoned") };
            return sys::LT_BUSY;
        }
    };
    let Some(runtime) = slot.as_ref() else {
        unsafe { write_error(error_buffer, error_capacity, "no guest session") };
        return sys::LT_INVALID;
    };
    match runtime.button(button, down != 0) {
        Ok(()) => sys::LT_OK,
        Err(error) => {
            unsafe { write_error(error_buffer, error_capacity, &error.to_string()) };
            error_code(&error)
        }
    }
}

#[unsafe(no_mangle)]
pub unsafe extern "C" fn lt_ios_pause(
    context: *mut LtIosContext,
    paused: u32,
    error_buffer: *mut c_char,
    error_capacity: usize,
) -> i32 {
    if context.is_null() {
        unsafe { write_error(error_buffer, error_capacity, "context is null") };
        return sys::LT_INVALID;
    }
    let context = unsafe { &*context };
    let slot = match context.runtime.lock() {
        Ok(v) => v,
        Err(_) => {
            unsafe { write_error(error_buffer, error_capacity, "runtime lock poisoned") };
            return sys::LT_BUSY;
        }
    };
    let Some(runtime) = slot.as_ref() else {
        unsafe { write_error(error_buffer, error_capacity, "no guest session") };
        return sys::LT_INVALID;
    };
    match runtime.pause(paused != 0) {
        Ok(()) => sys::LT_OK,
        Err(error) => {
            unsafe { write_error(error_buffer, error_capacity, &error.to_string()) };
            error_code(&error)
        }
    }
}

#[unsafe(no_mangle)]
pub unsafe extern "C" fn lt_ios_request_shutdown(
    context: *mut LtIosContext,
    error_buffer: *mut c_char,
    error_capacity: usize,
) -> i32 {
    if context.is_null() {
        unsafe { write_error(error_buffer, error_capacity, "context is null") };
        return sys::LT_INVALID;
    }
    let context = unsafe { &*context };
    let slot = match context.runtime.lock() {
        Ok(v) => v,
        Err(_) => {
            unsafe { write_error(error_buffer, error_capacity, "runtime lock poisoned") };
            return sys::LT_BUSY;
        }
    };
    let Some(runtime) = slot.as_ref() else {
        unsafe { write_error(error_buffer, error_capacity, "no guest session") };
        return sys::LT_INVALID;
    };
    match runtime.request_shutdown() {
        Ok(()) => sys::LT_OK,
        Err(error) => {
            unsafe { write_error(error_buffer, error_capacity, &error.to_string()) };
            error_code(&error)
        }
    }
}

#[unsafe(no_mangle)]
pub unsafe extern "C" fn lt_ios_runtime_destroy(
    context: *mut LtIosContext,
    error_buffer: *mut c_char,
    error_capacity: usize,
) -> i32 {
    if context.is_null() {
        unsafe { write_error(error_buffer, error_capacity, "context is null") };
        return sys::LT_INVALID;
    }
    let context = unsafe { &*context };
    let mut slot = match context.runtime.lock() {
        Ok(v) => v,
        Err(_) => {
            unsafe { write_error(error_buffer, error_capacity, "runtime lock poisoned") };
            return sys::LT_BUSY;
        }
    };
    let Some(runtime) = slot.take() else {
        return sys::LT_OK;
    };
    match runtime.destroy() {
        Ok(()) => sys::LT_OK,
        Err((runtime, error)) => {
            *slot = Some(runtime);
            unsafe { write_error(error_buffer, error_capacity, &error.to_string()) };
            error_code(&error)
        }
    }
}

#[unsafe(no_mangle)]
pub unsafe extern "C" fn lt_ios_context_close(
    context: *mut LtIosContext,
    error_buffer: *mut c_char,
    error_capacity: usize,
) -> i32 {
    if context.is_null() {
        return sys::LT_INVALID;
    }
    let value = unsafe { &*context };
    let can_close = match value.runtime.lock() {
        Ok(slot) => slot.is_none(),
        Err(_) => {
            unsafe { write_error(error_buffer, error_capacity, "runtime lock poisoned") };
            return sys::LT_BUSY;
        }
    };
    if !can_close {
        unsafe { write_error(error_buffer, error_capacity, "destroy the guest runtime before closing the library") };
        return sys::LT_BUSY;
    }
    drop(unsafe { Box::from_raw(context) });
    sys::LT_OK
}

#[unsafe(no_mangle)]
pub unsafe extern "C" fn lt_ios_string_free(value: *mut c_char) {
    if !value.is_null() {
        drop(unsafe { CString::from_raw(value) });
    }
}

#[unsafe(no_mangle)]
pub extern "C" fn lt_ios_core_version() -> *const c_char {
    concat!(env!("CARGO_PKG_VERSION"), "\0").as_ptr().cast()
}
