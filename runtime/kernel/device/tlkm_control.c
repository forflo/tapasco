#include <linux/slab.h>
#include <linux/gfp.h>
#include <linux/fs.h>
#include <linux/version.h>
#if LINUX_VERSION_CODE < KERNEL_VERSION(4, 11, 0)
#include <linux/sched.h>
#else
#include <linux/sched/signal.h>
#endif
#include "tlkm_logging.h"
#include "tlkm_control.h"
#include "tlkm_perfc.h"
#include "tlkm_device_rw.h"
#include "tlkm_device_ioctl.h"
#include "tlkm_device_mmap.h"
#include "user/tlkm_device_ioctl_cmds.h"

static const struct file_operations _tlkm_control_fops = {
	.unlocked_ioctl = tlkm_device_ioctl,
	.mmap = tlkm_device_mmap,
	.read = tlkm_device_read,
	.write = tlkm_device_write,
};

static int init_miscdev(struct tlkm_control *pctl)
{
	char fn[16];
	snprintf(fn, 16, TLKM_DEV_IOCTL_FN, pctl->dev_id);
	DEVLOG(pctl->dev_id, TLKM_LF_CONTROL, "creating miscdevice %s", fn);
	pctl->miscdev.minor = MISC_DYNAMIC_MINOR;
	pctl->miscdev.name = kstrdup(fn, GFP_KERNEL);
	pctl->miscdev.fops = &_tlkm_control_fops;
	return misc_register(&pctl->miscdev);
}

static void exit_miscdev(struct tlkm_control *pctl)
{
	misc_deregister(&pctl->miscdev);
	kfree(pctl->miscdev.name);
	pctl->miscdev.name = NULL;
	DEVLOG(pctl->dev_id, TLKM_LF_CONTROL, "destroyed miscdevice");
}

ssize_t tlkm_control_signal_slot_interrupt(struct tlkm_control *pctl,
					   const u32 s_id)
{
	static long max_outstanding = 0;
	BUG_ON(!pctl);
	mutex_lock(&pctl->out_mutex);
	while (pctl->outstanding > TLKM_CONTROL_BUFFER_SZ - 2) {
		DEVWRN(pctl->dev_id, "buffer thrashing, throttling write ...");
		mutex_unlock(&pctl->out_mutex);
		wait_event_interruptible(pctl->write_q,
					 pctl->outstanding <=
						 (TLKM_CONTROL_BUFFER_SZ / 2));
		if (signal_pending(current))
			return -ERESTARTSYS;
		mutex_lock(&pctl->out_mutex);
	}
	mutex_unlock(&pctl->out_mutex);
	DEVLOG(pctl->dev_id, TLKM_LF_CONTROL, "signaling slot #%u", s_id);
	mutex_lock(&pctl->out_mutex);
	pctl->out_slots[pctl->out_w_idx] = s_id;
	pctl->out_w_idx = (pctl->out_w_idx + 1) % TLKM_CONTROL_BUFFER_SZ;
	++pctl->outstanding;
	tlkm_perfc_signals_signaled_inc(pctl->dev_id);
	tlkm_perfc_outstanding_set(pctl->dev_id, pctl->outstanding);
	if (pctl->outstanding > max_outstanding) {
		max_outstanding = pctl->outstanding;
		tlkm_perfc_outstanding_high_watermark_set(pctl->dev_id,
							  max_outstanding);
	}
#ifndef NDEBUG
	if (pctl->outstanding >= TLKM_CONTROL_BUFFER_SZ)
		DEVWRN(pctl->dev_id,
		       "buffer size exceeded! expect missing data!");
#endif
	mutex_unlock(&pctl->out_mutex);
	wake_up_interruptible(&pctl->read_q);
	return sizeof(u32);
}

int tlkm_control_init(dev_id_t dev_id, struct tlkm_control **ppctl)
{
	int ret = 0;
	struct tlkm_control *p =
		(struct tlkm_control *)kzalloc(sizeof(*p), GFP_KERNEL);
	if (!p) {
		DEVERR(dev_id, "could not allocate struct tlkm_control");
		return -ENOMEM;
	}
	p->dev_id = dev_id;
	init_waitqueue_head(&p->read_q);
	init_waitqueue_head(&p->write_q);
	p->out_r_idx = 0;
	p->out_w_idx = 0;
	p->outstanding = 0;
	mutex_init(&p->out_mutex);
	if ((ret = init_miscdev(p))) {
		DEVERR(dev_id, "could not initialize control: %d", ret);
		goto err_miscdev;
	}
	*ppctl = p;
	DEVLOG(dev_id, TLKM_LF_CONTROL, "initialized control");
	return 0;

err_miscdev:
	kfree(p);
	return ret;
}

void tlkm_control_exit(struct tlkm_control *pctl)
{
	if (pctl) {
		exit_miscdev(pctl);
		DEVLOG(pctl->dev_id, TLKM_LF_CONTROL, "destroyed control");
		kfree(pctl);
	}
}
