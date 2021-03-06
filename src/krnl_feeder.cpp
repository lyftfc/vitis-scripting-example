#include <ap_int.h>
#include <ap_axi_sdata.h>
#include <hls_stream.h>

#define TRNX_WIDTH	32

typedef qdma_axis<16, 0, 0, 0> short_t;

void krnl_feeder (
		ap_uint<TRNX_WIDTH> *memIn,
		int nTrans,
		hls::stream<short_t> &ms2b,
		hls::stream<short_t> &ls2b
) {
#pragma HLS INTERFACE m_axi port = memIn offset = slave bundle = gmem
#pragma HLS INTERFACE axis port = ms2b
#pragma HLS INTERFACE axis port = ls2b
#pragma HLS INTERFACE s_axilite port = memIn
#pragma HLS INTERFACE s_axilite port = nTrans
#pragma HLS INTERFACE s_axilite port = return

	int i = 0;
	short_t m, l;
	for (i = 0; i < nTrans; i++) {
		ap_uint<TRNX_WIDTH> tr = memIn[i];
		ap_uint<16> md = tr.range(31, 16);
		ap_uint<16> ld = tr.range(15, 0);
		m.data = md;
		l.data = ld;
		m.keep_all();
		l.keep_all();
		m.last = 1;
		l.last = 1;
		ms2b.write(m);
		ls2b.write(l);
	}
}
