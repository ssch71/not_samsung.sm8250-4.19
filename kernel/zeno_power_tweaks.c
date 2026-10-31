// SPDX-License-Identifier: GPL-2.0
/* ZenoKernel: Native kernel thread to enforce VM efficiency without root */

#include <linux/kthread.h>
#include <linux/delay.h>
#include <linux/sched.h>

extern int vm_swappiness;
extern int vm_dirty_ratio;
extern int dirty_background_ratio;
extern unsigned long vm_dirty_bytes;
extern unsigned long dirty_background_bytes;

static int zeno_power_tweaks_thread(void *data)
{
    ssleep(45);

    while (!kthread_should_stop()) {
        WRITE_ONCE(vm_swappiness, 10);
        WRITE_ONCE(dirty_background_ratio, 5);
        WRITE_ONCE(vm_dirty_ratio, 10);
        WRITE_ONCE(vm_dirty_bytes, 0UL);
        WRITE_ONCE(dirty_background_bytes, 0UL);
        ssleep(60);
    }
    return 0;
}

static int __init zeno_power_tweaks_init(void)
{
    kthread_run(zeno_power_tweaks_thread, NULL, "zeno_power_tweaks");
    return 0;
}
late_initcall(zeno_power_tweaks_init);
