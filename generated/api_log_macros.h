// Automatically generated file
#include"api/z3.h"
#ifdef __GNUC__
#define _Z3_UNUSED __attribute__((unused))
#else
#define _Z3_UNUSED
#endif
#include "util/mutex.h"
extern atomic<bool> g_z3_log_enabled;
void ctx_enable_logging();
class z3_log_ctx { bool m_prev; public: z3_log_ctx() { ATOMIC_EXCHANGE(m_prev, g_z3_log_enabled, false); } ~z3_log_ctx() { if (m_prev) [[unlikely]] g_z3_log_enabled = true; } bool enabled() const { return m_prev; } };
void SetR(const void * obj);
void SetO(void * obj, unsigned pos);
void SetAO(void * obj, unsigned pos, unsigned idx);
#define RETURN_Z3(Z3RES) do { auto tmp_ret = Z3RES; if (_LOG_CTX.enabled()) [[unlikely]] { SetR(tmp_ret); } return tmp_ret; } while (0)
