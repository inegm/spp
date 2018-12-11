(
/* Server-side definitions

I chose to place the reverb inside the spp synth definition so that each
instance would have its own reverb space. I'd like to eventually replace
the reverb with a physical resonator model and that would certainly have
to be kept isolated between instances.
*/

SynthDef.new(\spp, {
	arg freq, amp, out, bufnum, mix, room, damp;
	var harm_osc, sig, reply_impulse, delay_impulse;

	harm_osc = Osc.ar(bufnum, freq, 0, amp, 0);
	sig = FreeVerb2.ar(harm_osc, harm_osc, mix, room, damp);
	Out.ar(out, sig);

	reply_impulse = Impulse.kr(10);
	delay_impulse = Delay1.kr(reply_impulse);

	SendReply.kr(
		reply_impulse,
		'/spp/scsynth/level',
		[
			Amplitude.ar(sig),
			K2A.ar(Peak.ar(sig, delay_impulse).lag(0, 3))
	]);
}).add;
)
