//
// Copyright (C) 2014-2018 Jens Korinth, TU Darmstadt
//
// This file is part of Tapasco (TaPaSCo).
//
// Tapasco is free software: you can redistribute it and/or modify
// it under the terms of the GNU Lesser General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// Tapasco is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU Lesser General Public License for more details.
//
// You should have received a copy of the GNU Lesser General Public License
// along with Tapasco.  If not, see <http://www.gnu.org/licenses/>.
//
//! @file	zynq_dmamgmt.h
//! @brief	Tapasco Platform Zynq: DMA buffer management.
//! @authors	J. Korinth, TU Darmstadt (jk@esa.cs.esa.tu-darmstadt.de)
//!
#ifndef ZYNQ_DMAMGMT_H__
#define ZYNQ_DMAMGMT_H__

#include "tlkm_types.h"

#define ZYNQ_DMAMGMT_POOLSZ		 	1024U

typedef u64 handle_t;

struct dma_buf_t {
	size_t len;
	unsigned long handle;
	dma_addr_t dma_addr;
	void * kvirt_addr;
};

int zynq_dmamgmt_init(void);
void zynq_dmamgmt_exit(void);
dma_addr_t zynq_dmamgmt_alloc(size_t const len, handle_t *hid);
int zynq_dmamgmt_dealloc(handle_t const id);
int zynq_dmamgmt_dealloc_dma(dma_addr_t const addr);
struct dma_buf_t *zynq_dmamgmt_get(handle_t const id);
ssize_t zynq_dmamgmt_get_id(dma_addr_t const addr);

#endif /* ZYNQ_DMAMGMT_H__ */
