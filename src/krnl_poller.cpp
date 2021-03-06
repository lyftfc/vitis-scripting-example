#include <ap_int.h>
#include <ap_axi_sdata.h>
#include <hls_stream.h>

#define TRNX_WIDTH	32

typedef qdma_axis<32, 0, 0, 0> short_t;

void krnl_poller (
		ap_uint<TRNX_WIDTH> *resOut,
		int nRes,
		hls::stream<short_t> &ms2b,
		hls::stream<short_t> &ls2b
) {
#pragma HLS INTERFACE m_axi port = resOut offset = slave bundle = gmem
#pragma HLS INTERFACE axis port = ms2b
#pragma HLS INTERFACE axis port = ls2b
#pragma HLS INTERFACE s_axilite port = resOut
#pragma HLS INTERFACE s_axilite port = nRes
#pragma HLS INTERFACE s_axilite port = return

	int i = 0;
	short_t m, l;
	for (i = 0; i < nRes; i++) {
		ap_uint<TRNX_WIDTH> r;
		m = ms2b.read();
		l = ls2b.read();
		// Cross-write the two
		r.range(15, 0) = m.data;
		r.range(31, 16) = l.data;
		resOut[i] = r;
	}
}
