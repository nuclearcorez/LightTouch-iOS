#ifndef LIGHTTOUCH_IOS_BRIDGE_H
#define LIGHTTOUCH_IOS_BRIDGE_H

#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct LtIosContext LtIosContext;

typedef struct LtIosStatus {
    uint32_t state; /* 0 stopped, 1 starting, 2 running, 3 paused, 4 stopping, 5 failed */
    uint32_t guest_shutdown_confirmed;
    uint32_t storage_failed;
    uint32_t dirty;
    int32_t engine_exit;
    uint64_t frames;
} LtIosStatus;

typedef struct LtIosFrameInfo {
    uint32_t width;
    uint32_t height;
    uint32_t stride;
    uint64_t sequence;
    uint64_t timestamp_ns;
    uint64_t bytes;
} LtIosFrameInfo;

const char *lt_ios_core_version(void);
int32_t lt_ios_context_open(const char *root, LtIosContext **out_context, char *error_buffer, size_t error_capacity);
int32_t lt_ios_records_json(LtIosContext *context, char **out_json, char *error_buffer, size_t error_capacity);
int32_t lt_ios_start(LtIosContext *context, const char *record_id, const char *engine_path, uint32_t recover_dirty, char *error_buffer, size_t error_capacity);
int32_t lt_ios_poll(LtIosContext *context, LtIosStatus *out_status, char *error_buffer, size_t error_capacity);
int32_t lt_ios_copy_frame(LtIosContext *context, uint8_t *pixels, size_t capacity, uint64_t *since_sequence, LtIosFrameInfo *out_info, char *error_buffer, size_t error_capacity);
int32_t lt_ios_touch(LtIosContext *context, uint64_t timestamp_ns, uint32_t contact_id, uint32_t phase, double x, double y, char *error_buffer, size_t error_capacity);
int32_t lt_ios_button(LtIosContext *context, uint32_t button, uint32_t down, char *error_buffer, size_t error_capacity);
int32_t lt_ios_pause(LtIosContext *context, uint32_t paused, char *error_buffer, size_t error_capacity);
int32_t lt_ios_request_shutdown(LtIosContext *context, char *error_buffer, size_t error_capacity);
int32_t lt_ios_runtime_destroy(LtIosContext *context, char *error_buffer, size_t error_capacity);
int32_t lt_ios_context_close(LtIosContext *context, char *error_buffer, size_t error_capacity);
void lt_ios_string_free(char *value);

#ifdef __cplusplus
}
#endif
#endif
