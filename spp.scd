(
{
(PathName(thisProcess.nowExecutingPath).pathOnly ++ "spp_def.scd").loadPaths;
(PathName(thisProcess.nowExecutingPath).pathOnly ++ "gui_place.scd").loadPaths;
(PathName(thisProcess.nowExecutingPath).pathOnly ++ "gui_ctrls.scd").loadPaths;
}.doOnServerBoot;
o = Server.local.options;
o.device = "ES-8";
o.numOutputBusChannels = 8;
s.reboot;
s.meter;
)
(
~init_synth = {
	arg n_partials=128, freq=60.0, amp=1.0, level=0.4, out=0,
		mix=0.0, room=0.3, damp=0.5;
	var osc_levels_path, synth, harm_array, harm_buffer, oscillator;

	harm_array = Harmonics.new(n_partials);
	harm_buffer = Buffer.alloc(s, 512, 1);
	oscillator = Synth.new(
		"spp", [
			\n_partials, n_partials,
			\freq, freq,
			\amp, amp,
			\level, level,
			\out, out,
			\bufnum, harm_buffer.bufnum,
			\mix, mix,
			\room, room,
			\damp, damp;
	]);

	synth = Dictionary.new;
	synth.add(\n_partials -> n_partials);
	synth.add(\harm_array -> harm_array);
	synth.add(\harm_buffer -> harm_buffer);
	synth.add(\oscillator -> oscillator);
	synth.add(\out_channel -> out);
	synth.add(\node -> oscillator.nodeID);

	synth;
};

~launch_spp = {
	var configs, osc_paths, gui_node;
	var synth;
	var window, param_position=0;

	// Configuration values.
	configs = Dictionary.new;
	configs.add(\window_title -> "sine plus plus");
	configs.add(\window_left -> 200);
	configs.add(\window_top -> 200);
	configs.add(\window_width -> 880);
	configs.add(\window_height -> 500);
	configs.add(\window_background_color -> Color.gray);
	configs.add(\window_margin -> 20);
	configs.add(\inner_margin -> 10);
	configs.add(\main_font -> Font("Menlo", 10));
	configs.add(\main_font_color -> Color.black);
	configs.add(\title_font -> Font("Menlo", 13));
	configs.add(\title_height -> 20);
	configs.add(\parameter_width -> 40);
	configs.add(\label_width -> 40);
	configs.add(\label_height -> 15);
	configs.add(\button_width -> 20);
	configs.add(\button_height -> 20);
	configs.add(\button_font -> Font("Menlo", 10));
	configs.add(\button_font_color -> Color.black);
	configs.add(\button_back_color -> Color.fromHexString("B7B7B7"));
	configs.add(\button_active_font_color -> Color.black);
	configs.add(\button_active_back_color -> Color.fromHexString("#f1d637"));
	configs.add(\slider_width -> 15);
	configs.add(\slider_height -> 200);
	configs.add(\level_width -> 10);
	configs.add(\level_height -> 195);
	configs.add(\string_prec -> 6);

	// Initialize the synth.
	synth = ~init_synth.value();

	osc_paths = Dictionary.new;
	osc_paths.add(\freq -> "/spp/freq");
	osc_paths.add(\level -> "/spp/level");
	osc_paths.add(\amp -> "/spp/amp");
	osc_paths.add(\verb_mix -> "/spp/verb/mix");
	osc_paths.add(\verb_room -> "/spp/verb/room");
	osc_paths.add(\verb_damp -> "/spp/verb/damp");
	osc_paths.add(\mode -> "/spp/mode");
	osc_paths.add(\ramp_start -> "/spp/ramp/start");
	osc_paths.add(\ramp_step -> "/spp/ramp/step");
	osc_paths.add(\decay_k -> "/spp/decay/k");
	osc_paths.add(\geom_k -> "/spp/geom/k");
	osc_paths.add(\formant_center -> "/spp/formant/center");
	osc_paths.add(\formant_width -> "/spp/formant/width");
	osc_paths.add(\teeth_start -> "/spp/teeth/start");
	osc_paths.add(\teeth_space -> "/spp/teeth/space");
	osc_paths.add(\cutoff_n -> "/spp/cutoff/n");
	osc_paths.add(\shelf_start -> "/spp/shelf/start");
	osc_paths.add(\shelf_end -> "/spp/shelf/end");
	osc_paths.add(\shelf_slevel -> "/spp/shelf/slevel");
	osc_paths.add(\shelf_elevel -> "/spp/shelf/elevel");
	osc_paths.add(\amps -> "/spp/amps");

	// Build the GUI
	window = Window.new(
		configs.at(\window_title),
		Rect.new(
			configs.at(\window_left),
			configs.at(\window_top),
			configs.at(\window_width),
			configs.at(\window_height)
	));
	window.view.background_(configs.at(\window_background_color));
	window.alwaysOnTop_(false);
	window.onClose = {
		synth.at(\oscillator).free;
		synth.at(\harm_buffer).free;
	};

	~gui_place_title.value(window, configs);

	// Place nodeID
	/*
	gui_node = StaticText(window.view, Rect.new(
		configs.at(\window_margin),
		configs.at(\window_height) - 30,
		200,
		20
	));
	gui_node.font_(configs.at(\main_font));
	gui_node.stringColor_(configs.at(\button_back_color));
	gui_node.string_(format(
		"%:%/spp/%/...",
		NetAddr.localAddr.ip,
		NetAddr.localAddr.port,
		synth.at(\node))
	).align_(\left);
	*/

	param_position = ~gui_global_ctrl.value(
		window,
		(
			configs.at(\title_height) +
			configs.at(\window_margin) +
			(2 * configs.at(\inner_margin))
		),
		param_position,
		configs,
		synth,
		osc_paths
	);

	param_position = ~gui_harm_ctrl.value(
		window,
		(
			configs.at(\title_height) +
			configs.at(\window_margin) +
			(2 * configs.at(\inner_margin))
		),
		param_position + 1,
		configs,
		synth,
		osc_paths
	);

	param_position = ~gui_reverb_ctrl.value(
		window,
		(
			configs.at(\title_height) +
			configs.at(\window_margin) +
			(2 * configs.at(\inner_margin))
		),
		param_position + 1,
		configs,
		synth,
		osc_paths
	);

	window.front;
};

~launch_spp.value();
)
