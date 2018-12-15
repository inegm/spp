(
/* These functions generate the control elements and define their behaviors.
None of this is optimally written and there's much room for improvement in
future iterations.
*/

~gui_draw_amps = {
	arg window, configs, amps;
	var height, width, top, left, spacing=0, position=0;

	height = 150;
	width = configs.at(\window_width);
	top = configs.at(\window_height) - height;
	left = 0;

	window.drawFunc = {
		var bar_width;

		bar_width = ((width + spacing) / amps.size) - spacing;
		amps.do({
			arg amp;

			Pen.addRect(Rect(
				// left + (position * (bar_width + spacing)),
				position * (bar_width + spacing),
				top + (height - (amp * height)),
				bar_width,
				(amp * height)
			));
			position = position + 1;
		});
		Pen.fillColor = Color.fromHexString("#222222");
		Pen.strokeColor = Color.fromHexString("#222222");
		Pen.fillStroke;
	};
	window.refresh;
};

~gui_global_ctrl = {
	arg window, top, position, configs, synth, osc_paths,
	    freq_val=60.0, min_freq=10.0, max_freq=500.0,
	    level_val=0.4, min_level=0.0, max_level=1.0;
	var freq_label, freq_val_label, freq_slider,
	    level_label, level_val_label, level_slider, mute_btn,
	    level_indicator, level_indicator_osc,
		freq_osc, amp_osc, level_osc, amps_osc,
		top_offset;

	top_offset = ~gui_offset_button.value(top, configs);
	freq_label = ~gui_place_label.value(
		window, configs, position, top_offset, "freq"
	);
	top_offset = ~gui_offset_label.value(top_offset, configs);
	freq_slider = ~gui_place_slider.value(
		window, configs, position, top_offset
	);
	freq_slider.value_(freq_val.explin(min_freq, max_freq, 0.0, 1.0));
	freq_slider.action_({
		arg obj;
		freq_val = obj.value.linexp(0.0, 1.0, min_freq, max_freq);
		freq_val_label.string_(freq_val.asStringPrec(4));
		synth.at(\oscillator).set(\freq, freq_val);
	});
	top_offset = ~gui_offset_slider.value(top_offset, configs);
	freq_val_label = ~gui_place_val_label.value(
		window, configs, position, top_offset
	);
	freq_val_label.string_(freq_val.asStringPrec(4)).align_(\center);
	freq_osc = OSCFunc({
		arg msg;
		{
			freq_val = msg[1];
			freq_slider.value_(freq_val.explin(min_freq, max_freq, 0.0, 1.0));
			freq_val_label.string_(freq_val.asStringPrec(4));
			synth.at(\oscillator).set(\freq, freq_val);
		}.defer;
	}, osc_paths.at(\freq));

	position = position + 1;

	top_offset = ~gui_offset_button.value(top, configs);
	level_label = ~gui_place_label.value(
		window, configs, position, top_offset, "level"
	);
	top_offset = ~gui_offset_label.value(top_offset, configs);
	level_slider = ~gui_place_slider.value(
		window, configs, position, top_offset
	);
	level_slider.value_(level_val.linlin(min_level, max_level, 0.0, 1.0));
	level_slider.action_({
		arg obj;
		level_val = obj.value.linlin(0.0, 1.0, min_level, max_level);
		level_val_label.string_(level_val.asStringPrec(2));
		synth.at(\oscillator).set(\level, level_val);
	});
	top_offset = ~gui_offset_slider.value(top_offset, configs);
	level_val_label = ~gui_place_val_label.value(
		window, configs, position, top_offset
	);
	level_val_label.string_(level_val.asStringPrec(2)).align_(\center);
	level_osc = OSCFunc({
		arg msg;
		{ level_slider.valueAction = msg[1] }.defer;
	}, osc_paths.at(\level));

	amp_osc = OSCFunc({
		arg msg;
		var amp_val;
		{
			amp_val = msg[1];
			synth.at(\oscillator).set(\amp, amp_val);
		}.defer;
	}, osc_paths.at(\amp));

	amps_osc = OSCFunc({
		arg msg;
		var path, amps;
		{
			path = msg.removeAt(0);
			amps = msg.collect({ arg item; min(1.0, (item / 100.0 ))});
			if (amps.size < synth.at(\n_partials),
				{
					amps = amps.insert(amps.size, 0.0);
					amps = amps.clipExtend(synth.at(\n_partials));
				}, {
					amps = amps[0..synth.at(\n_partials)];
				}
			);
			synth.at(\harm_buffer).sine2(
				synth.at(\harm_array).ramp(1.0, 1.0), amps
			);
			~gui_draw_amps.value(window, configs, amps);
		}.defer;
	}, osc_paths.at(\amps));

	position = position + 1;

	top_offset = ~gui_offset_button.value(top, configs);
	top_offset = ~gui_offset_label.value(top_offset, configs);
	level_indicator = ~gui_place_level.value(
		window, configs, position, top_offset
	);
	level_indicator.drawsPeak = true;
	level_indicator.style = \led;
	level_indicator.stepWidth = 3;
	level_indicator.warning = -3.dbamp;
	level_indicator.critical = -1.dbamp;
	level_indicator_osc = OSCFunc({
		arg msg;
		{
			level_indicator.value = msg[3].ampdb.linlin(-40, 0, 0, 1);
			level_indicator.peakLevel = msg[4].ampdb.linlin(-40, 0, 0, 1);
		}.defer;
	}, "/spp/scsynth/level", s.addr);

	freq_slider.onClose = {
		freq_osc.free;
		level_osc.free;
		level_indicator_osc.free;
		amp_osc.free;
		amps_osc.free;
	 };

	position + 1;
};

~gui_harm_ctrl = {
	arg window, top, position, configs, synth, osc_paths;
	var top_offset, initial_position;
	// buttons
	var ramp_button, decay_button, geom_button,
	    formant_button, teeth_button,
	    cutoff_button, shelf_button;
	// labels
	var ramp_start_label, ramp_step_label,
	    decay_k_label, geom_k_label,
	    formant_center_label, formant_width_label,
	    teeth_space_label, teeth_start_label,
	    cutoff_n_label,
	    shelf_start_label, shelf_end_label,
	    shelf_slevel_label, shelf_elevel_label;
	// sliders
	var ramp_start_slider, ramp_step_slider,
	    decay_k_slider, geom_k_slider,
	    formant_center_slider, formant_width_slider,
	    teeth_space_slider, teeth_start_slider,
	    cutoff_n_slider,
	    shelf_start_slider, shelf_end_slider,
	    shelf_slevel_slider, shelf_elevel_slider;
	// val_labels
	var ramp_start_val_label, ramp_step_val_label,
	    decay_k_val_label, geom_k_val_label,
	    formant_center_val_label, formant_width_val_label,
	    teeth_space_val_label, teeth_start_val_label,
	    cutoff_n_val_label,
	    shelf_start_val_label, shelf_end_val_label,
	    shelf_slevel_val_label, shelf_elevel_val_label;
	// ramp params
	var ramp_start_val=0.5,
	    ramp_start_min=0.0,
	    ramp_start_max=1.0,
    	ramp_step_val=0.0,
    	ramp_step_min=0.0,
	    ramp_step_max=0.0;
	// decay params
	var decay_k_val=1.0,
	    decay_k_min=0.1,
	    decay_k_max=2.0;
	// geom params
	var geom_k_val=1.5,
	    geom_k_min=1.0,
	    geom_k_max=3.0;
	// formant params
	var formant_center_val=0,
	    formant_center_min=0,
	    formant_center_max=synth.at(\n_partials) - 1,
	    formant_width_val=30,
	    formant_width_min=1,
	    formant_width_max=synth.at(\n_partials) - 1;
	// teeth params
	var teeth_space_val=6,
		teeth_space_min=0,
		teeth_space_max=synth.at(\n_partials) - 1,
		teeth_start_val=0,
		teeth_start_min=0,
		teeth_start_max=synth.at(\n_partials) - 2;
	// cutoff params
	var cutoff_n_val=3,
	    cutoff_n_min=0,
		cutoff_n_max=synth.at(\n_partials) - 1;
	// shelf params
	var shelf_start_val=0,
	    shelf_start_min=0,
		shelf_start_max=synth.at(\n_partials) - 1,
		shelf_end_val=6,
		shelf_end_min=0,
		shelf_end_max=synth.at(\n_partials) - 1,
		shelf_slevel_val=1.0,
		shelf_slevel_min=0.0,
		shelf_slevel_max=1.0,
		shelf_elevel_val=0.0,
		shelf_elevel_min=0.0,
		shelf_elevel_max=1.0;
	// osc
	var mode_osc,
		ramp_start_osc, ramp_step_osc,
		decay_k_osc,
		geom_k_osc,
		formant_center_osc, formant_width_osc,
		teeth_start_osc, teeth_space_osc,
		cutoff_n_osc,
		shelf_start_osc, shelf_end_osc,
		shelf_slevel_osc, shelf_elevel_osc;

	initial_position = position;

	mode_osc = OSCFunc({
		arg msg;
		{
			switch (msg[1],
				0, {
					ramp_button.valueAction = 0;
					decay_button.valueAction = 0;
					geom_button.valueAction = 0;
					formant_button.valueAction = 0;
					teeth_button.valueAction = 0;
					cutoff_button.valueAction = 0;
					shelf_button.valueAction = 0;
				},
				'r', {
					ramp_button.valueAction = 1;
				},
				'd', {
					decay_button.valueAction = 1;
				},
				'g', {
					geom_button.valueAction = 1;
				},
				'f', {
					formant_button.valueAction = 1;
				},
				't', {
					teeth_button.valueAction = 1;
				},
				'c', {
					cutoff_button.valueAction = 1;
				},
				's', {
					shelf_button.valueAction = 1;
				}
			);
		}.defer;
	}, osc_paths.at(\mode));

	// RAMP
	top_offset = top;
	/* Setting these two values here because negative default values are not
	allowed. */
	ramp_step_val = -0.0025;
	ramp_step_min = -0.02;
	ramp_button = ~gui_place_button.value(
		window, configs, position, top_offset, "R"
	);
	ramp_button.action_({
		arg obj;
		switch (obj.value,
			0, {
				synth.at(\harm_buffer).sine1(0!configs.at(\n_partials));
				~gui_draw_amps.value(
					window, configs, 0!configs.at(\n_partials)
				);
			}, 1, {
				var amps;
				[decay_button, geom_button, formant_button, teeth_button,
				 cutoff_button, shelf_button].do({
					 arg btn; btn.value_(0);
				});
				amps = synth.at(\harm_array).ramp(
					ramp_start_val, ramp_step_val
				);
				synth.at(\harm_buffer).sine2(
					synth.at(\harm_array).ramp(1.0, 1.0), amps
				);
				~gui_draw_amps.value(window, configs, amps);
			}
		)
	});

	top_offset = ~gui_offset_button.value(top, configs);
	ramp_start_label = ~gui_place_label.value(
		window, configs, position, top_offset, "start"
	);
	top_offset = ~gui_offset_label.value(top_offset, configs);
	ramp_start_slider = ~gui_place_slider.value(
		window, configs, position, top_offset
	);
	ramp_start_slider.value_(
		ramp_start_val.linlin(ramp_start_min, ramp_start_max, 0.0, 1.0)
	);
	ramp_start_slider.action_({
		arg obj;
		ramp_start_val = obj.value.linlin(
			0.0, 1.0, ramp_start_min, ramp_start_max
		);
		ramp_start_val_label.string_(ramp_start_val.asStringPrec(2));
		if (ramp_button.value == 1) {
			var amps;
			amps = synth.at(\harm_array).ramp(ramp_start_val, ramp_step_val);
			synth.at(\harm_buffer).sine2(
				synth.at(\harm_array).ramp(1.0, 1.0), amps
			);
			~gui_draw_amps.value(window, configs, amps);
		}
	});
	top_offset = ~gui_offset_slider.value(top_offset, configs);
	ramp_start_val_label = ~gui_place_val_label.value(
		window, configs, position, top_offset
	);
	ramp_start_val_label.string_(
		ramp_start_val.asStringPrec(2)
	).align_(\center);
	ramp_start_osc = OSCFunc({
		arg msg;
		{ ramp_start_slider.valueAction = msg[1]; }.defer;
	}, osc_paths.at(\ramp_start));

	position = position + 1;

	top_offset = ~gui_offset_button.value(top, configs);
	ramp_step_label = ~gui_place_label.value(
		window, configs, position, top_offset, "step"
	);
	top_offset = ~gui_offset_label.value(top_offset, configs);
	ramp_step_slider = ~gui_place_slider.value(
		window, configs, position, top_offset
	);
	ramp_step_slider.value_(
		ramp_step_val.linlin(ramp_step_min, ramp_step_max, 0.0, 1.0)
	);
	ramp_step_slider.action_({
		arg obj;
		ramp_step_val = obj.value.linlin(
			0.0, 1.0, ramp_step_min, ramp_step_max
		);
		ramp_step_val_label.string_(ramp_step_val.asStringPrec(2));
		if (ramp_button.value == 1) {
			var amps;
			amps = synth.at(\harm_array).ramp(ramp_start_val, ramp_step_val);
			synth.at(\harm_buffer).sine2(
				synth.at(\harm_array).ramp(1.0, 1.0), amps
			);
			~gui_draw_amps.value(window, configs, amps);
		}
	});
	top_offset = ~gui_offset_slider.value(top_offset, configs);
	ramp_step_val_label = ~gui_place_val_label.value(
		window, configs, position, top_offset
	);
	ramp_step_val_label.string_(ramp_step_val.asStringPrec(2)).align_(\center);
	ramp_step_osc = OSCFunc({
		arg msg;
		{ ramp_step_slider.valueAction = msg[1]; }.defer;
	}, osc_paths.at(\ramp_step));
	ramp_start_slider.onClose = {
		mode_osc.free;
		ramp_step_osc.free;
		ramp_start_osc.free;
	};

	position = position + 1;

	// DECAY
	top_offset = top;
	decay_button = ~gui_place_button.value(
		window, configs, position, top_offset, "D"
	);
	decay_button.action_({
		arg obj;
		switch (obj.value,
			0, {
				synth.at(\harm_buffer).sine1(0!configs.at(\n_partials));
				~gui_draw_amps.value(
					window, configs, 0!configs.at(\n_partials)
				);
			}, 1, {
				var amps;
				[ramp_button, geom_button, formant_button, teeth_button,
				 cutoff_button, shelf_button].do({
					 arg btn; btn.value_(0);
				});
				amps = synth.at(\harm_array).decay(decay_k_val);
				synth.at(\harm_buffer).sine2(
					synth.at(\harm_array).ramp(1.0, 1.0), amps
				);
				~gui_draw_amps.value(window, configs, amps);
			}
		)
	});

	top_offset = ~gui_offset_button.value(top, configs);
	decay_k_label = ~gui_place_label.value(
		window, configs, position, top_offset, "k"
	);
	top_offset = ~gui_offset_label.value(top_offset, configs);
	decay_k_slider = ~gui_place_slider.value(
		window, configs, position, top_offset
	);
	decay_k_slider.value_(
		decay_k_val.explin(decay_k_min, decay_k_max, 0.0, 1.0)
	);
	decay_k_slider.action_({
		arg obj;
		decay_k_val = obj.value.linexp(0.0, 1.0, decay_k_min, decay_k_max);
		decay_k_val_label.string_(decay_k_val.asStringPrec(3));
		if (decay_button.value == 1) {
			var amps;
			amps = synth.at(\harm_array).decay(decay_k_val);
			synth.at(\harm_buffer).sine2(
				synth.at(\harm_array).ramp(1.0, 1.0), amps
			);
			~gui_draw_amps.value(window, configs, amps);
		}
	});
	top_offset = ~gui_offset_slider.value(top_offset, configs);
	decay_k_val_label = ~gui_place_val_label.value(
		window, configs, position, top_offset
	);
	decay_k_val_label.string_(decay_k_val.asStringPrec(3)).align_(\center);
	decay_k_osc = OSCFunc({
		arg msg;
		{ decay_k_slider.valueAction = msg[1]; }.defer;
	}, osc_paths.at(\decay_k));
	decay_k_slider.onClose = { decay_k_osc.free; };

	position = position + 1;

	// GEOM
	top_offset = top;
	geom_button = ~gui_place_button.value(
		window, configs, position, top_offset, "G"
	);
	geom_button.action_({
		arg obj;
		switch (obj.value,
			0, {
				synth.at(\harm_buffer).sine1(0!configs.at(\n_partials));
				~gui_draw_amps.value(
					window, configs, 0!configs.at(\n_partials)
				);
			}, 1, {
				var amps;
				[ramp_button, decay_button, formant_button, teeth_button,
				 cutoff_button, shelf_button].do({
					 arg btn; btn.value_(0);
				});
				amps = synth.at(\harm_array).geom(geom_k_val);
				synth.at(\harm_buffer).sine2(
					synth.at(\harm_array).ramp(1.0, 1.0), amps
				);
				~gui_draw_amps.value(window, configs, amps);
			}
		)
	});

	top_offset = ~gui_offset_button.value(top, configs);
	geom_k_label = ~gui_place_label.value(
		window, configs, position, top_offset, "k"
	);
	top_offset = ~gui_offset_label.value(top_offset, configs);
	geom_k_slider = ~gui_place_slider.value(
		window, configs, position, top_offset
	);
	geom_k_slider.value_(geom_k_val.explin(geom_k_min, geom_k_max, 0.0, 1.0));
	geom_k_slider.action_({
		arg obj;
		geom_k_val = obj.value.linexp(0.0, 1.0, geom_k_min, geom_k_max);
		geom_k_val_label.string_(geom_k_val.asStringPrec(3));
		if (geom_button.value == 1) {
			var amps;
			amps = synth.at(\harm_array).geom(geom_k_val);
			synth.at(\harm_buffer).sine2(
				synth.at(\harm_array).ramp(1.0, 1.0), amps
			);
			~gui_draw_amps.value(window, configs, amps);
		}
	});
	top_offset = ~gui_offset_slider.value(top_offset, configs);
	geom_k_val_label = ~gui_place_val_label.value(
		window, configs, position, top_offset
	);
	geom_k_val_label.string_(geom_k_val.asStringPrec(3)).align_(\center);
	geom_k_osc = OSCFunc({
		arg msg;
		{ geom_k_slider.valueAction = msg[1]; }.defer;
	}, osc_paths.at(\geom_k));
	geom_k_slider.onClose = { geom_k_osc.free; };

	position = position + 1;

	// Formant
	top_offset = top;
	formant_button = ~gui_place_button.value(
		window, configs, position, top_offset, "F"
	);
	formant_button.action_({
		arg obj;
		switch (obj.value,
			0, {
				synth.at(\harm_buffer).sine1(0!configs.at(\n_partials));
				~gui_draw_amps.value(
					window, configs, 0!configs.at(\n_partials)
				);
			}, 1, {
				var amps;
				[ramp_button, decay_button, geom_button, teeth_button,
				 cutoff_button, shelf_button].do({
					 arg btn; btn.value_(0);
				});
				amps = synth.at(\harm_array).formant(
					formant_center_val, formant_width_val
				);
				synth.at(\harm_buffer).sine2(
					synth.at(\harm_array).ramp(1.0, 1.0), amps
				);
				~gui_draw_amps.value(window, configs, amps);
			}
		)
	});

	top_offset = ~gui_offset_button.value(top, configs);
	formant_center_label = ~gui_place_label.value(
		window, configs, position, top_offset, "center"
	);
	top_offset = ~gui_offset_label.value(top_offset, configs);
	formant_center_slider = ~gui_place_slider.value(
		window, configs, position, top_offset
	);
	formant_center_slider.value_(formant_center_val.linlin(
		formant_center_min, formant_center_max, 0.0, 1.0)
	);
	formant_center_slider.action_({
		arg obj;
		formant_center_val = round(obj.value.linlin(
			0.0, 1.0, formant_center_min, formant_center_max)
		);
		formant_center_val_label.string_(formant_center_val);
		if (formant_button.value == 1) {
			var amps;
			amps = synth.at(\harm_array).formant(
				formant_center_val, formant_width_val
			);
			synth.at(\harm_buffer).sine2(
				synth.at(\harm_array).ramp(1.0, 1.0), amps
			);
			~gui_draw_amps.value(window, configs, amps);
		}
	});
	top_offset = ~gui_offset_slider.value(top_offset, configs);
	formant_center_val_label = ~gui_place_val_label.value(
		window, configs, position, top_offset
	);
	formant_center_val_label.string_(
		round(formant_center_val)
	).align_(\center);
	formant_center_osc = OSCFunc({
		arg msg;
		{ formant_center_slider.valueAction = msg[1]; }.defer;
	}, osc_paths.at(\formant_center));

	position = position + 1;

	top_offset = top;
	top_offset = ~gui_offset_button.value(top, configs);
	formant_width_label = ~gui_place_label.value(
		window, configs, position, top_offset, "width"
	);
	top_offset = ~gui_offset_label.value(top_offset, configs);
	formant_width_slider = ~gui_place_slider.value(
		window, configs, position, top_offset
	);
	formant_width_slider.value_(formant_width_val.linlin(
		formant_width_min, formant_width_max, 0.0, 1.0)
	);
	formant_width_slider.action_({
		arg obj;
		formant_width_val = round(obj.value.linlin(
			0.0, 1.0, formant_width_min, formant_width_max)
		);
		formant_width_val_label.string_(formant_width_val);
		if (formant_button.value == 1) {
			var amps;
			amps = synth.at(\harm_array).formant(
				formant_center_val, formant_width_val
			);
			synth.at(\harm_buffer).sine2(
				synth.at(\harm_array).ramp(1.0, 1.0), amps
			);
			~gui_draw_amps.value(window, configs, amps);
		}
	});
	top_offset = ~gui_offset_slider.value(top_offset, configs);
	formant_width_val_label = ~gui_place_val_label.value(
		window, configs, position, top_offset
	);
	formant_width_val_label.string_(round(formant_width_val)).align_(\center);
	formant_width_osc = OSCFunc({
		arg msg;
		{ formant_width_slider.valueAction = msg[1]; }.defer;
	}, osc_paths.at(\formant_width));
	formant_center_slider.onClose = {
		formant_center_osc.free;
		formant_width_osc.free;
	};

	position = position + 1;

	// Teeth
	top_offset = top;
	teeth_button = ~gui_place_button.value(
		window, configs, position, top_offset, "T"
	);
	teeth_button.action_({
		arg obj;
		switch (obj.value,
			0, {
				synth.at(\harm_buffer).sine1(0!configs.at(\n_partials));
				~gui_draw_amps.value(
					window, configs, 0!configs.at(\n_partials)
				);
			}, 1, {
				var amps;
				[ramp_button, decay_button, geom_button, formant_button,
				 cutoff_button, shelf_button].do({
					 arg btn; btn.value_(0);
				});
				amps = synth.at(\harm_array).teeth(
					teeth_space_val, teeth_start_val
				);
				synth.at(\harm_buffer).sine2(
					synth.at(\harm_array).ramp(1.0, 1.0), amps
				);
				~gui_draw_amps.value(window, configs, amps);
			}
		)
	});

	top_offset = top;
	top_offset = ~gui_offset_button.value(top, configs);
	teeth_start_label = ~gui_place_label.value(
		window, configs, position, top_offset, "start"
	);
	top_offset = ~gui_offset_label.value(top_offset, configs);
	teeth_start_slider = ~gui_place_slider.value(
		window, configs, position, top_offset
	);
	teeth_start_slider.value_(teeth_start_val.linlin(
		teeth_start_min, teeth_start_max, 0.0, 1.0)
	);
	teeth_start_slider.action_({
		arg obj;
		teeth_start_val = round(obj.value.linlin(
			0.0, 1.0, teeth_start_min, teeth_start_max)
		);
		teeth_start_val_label.string_(teeth_start_val);
		if (teeth_button.value == 1) {
			var amps;
			amps = synth.at(\harm_array).teeth(
				teeth_space_val, teeth_start_val
			);
			synth.at(\harm_buffer).sine2(
				synth.at(\harm_array).ramp(1.0, 1.0), amps
			);
			~gui_draw_amps.value(window, configs, amps);
		}
	});
	top_offset = ~gui_offset_slider.value(top_offset, configs);
	teeth_start_val_label = ~gui_place_val_label.value(
		window, configs, position, top_offset
	);
	teeth_start_val_label.string_(round(teeth_start_val)).align_(\center);
	teeth_start_osc = OSCFunc({
		arg msg;
		{ teeth_start_slider.valueAction = msg[1]; }.defer;
	}, osc_paths.at(\teeth_start));

	position = position + 1;

	top_offset = ~gui_offset_button.value(top, configs);
	teeth_space_label = ~gui_place_label.value(
		window, configs, position, top_offset, "space"
	);
	top_offset = ~gui_offset_label.value(top_offset, configs);
	teeth_space_slider = ~gui_place_slider.value(
		window, configs, position, top_offset
	);
	teeth_space_slider.value_(teeth_space_val.linlin(
		teeth_space_min, teeth_space_max, 0.0, 1.0)
	);
	teeth_space_slider.action_({
		arg obj;
		teeth_space_val = round(obj.value.linlin(
			0.0, 1.0, teeth_space_min, teeth_space_max)
		);
		teeth_space_val_label.string_(teeth_space_val);
		if (teeth_button.value == 1) {
			var amps;
			amps = synth.at(\harm_array).teeth(
				teeth_space_val, teeth_start_val
			);
			synth.at(\harm_buffer).sine2(
				synth.at(\harm_array).ramp(1.0, 1.0), amps
			);
			~gui_draw_amps.value(window, configs, amps);
		}
	});
	top_offset = ~gui_offset_slider.value(top_offset, configs);
	teeth_space_val_label = ~gui_place_val_label.value(
		window, configs, position, top_offset
	);
	teeth_space_val_label.string_(round(teeth_space_val)).align_(\center);
	teeth_space_osc = OSCFunc({
		arg msg;
		{ teeth_space_slider.valueAction = msg[1]; }.defer;
	}, osc_paths.at(\teeth_space));
	teeth_start_slider.onClose = {
		teeth_start_osc.free;
		teeth_space_osc.free;
	};

	position = position + 1;

	// CUTOFF
	top_offset = top;
	cutoff_button = ~gui_place_button.value(
		window, configs, position, top_offset, "C"
	);
	cutoff_button.action_({
		arg obj;
		switch (obj.value,
			0, {
				synth.at(\harm_buffer).sine1(0!configs.at(\n_partials));
				~gui_draw_amps.value(
					window, configs, 0!configs.at(\n_partials)
				);
			}, 1, {
				var amps;
				[ramp_button, decay_button, geom_button, formant_button,
				 teeth_button, shelf_button].do({
					 arg btn; btn.value_(0);
				});
				amps = synth.at(\harm_array).cutoff(cutoff_n_val);
				synth.at(\harm_buffer).sine2(
					synth.at(\harm_array).ramp(1.0, 1.0), amps
				);
				~gui_draw_amps.value(window, configs, amps);
			}
		)
	});

	top_offset = top;
	top_offset = ~gui_offset_button.value(top, configs);
	cutoff_n_label = ~gui_place_label.value(
		window, configs, position, top_offset, "n"
	);
	top_offset = ~gui_offset_label.value(top_offset, configs);
	cutoff_n_slider = ~gui_place_slider.value(
		window, configs, position, top_offset
	);
	cutoff_n_slider.value_(cutoff_n_val.linlin(
		cutoff_n_min, cutoff_n_max, 0.0, 1.0)
	);
	cutoff_n_slider.action_({
		arg obj;
		cutoff_n_val = round(obj.value.linlin(
			0.0, 1.0, cutoff_n_min, cutoff_n_max)
		);
		cutoff_n_val_label.string_(cutoff_n_val);
		if (cutoff_button.value == 1) {
			var amps;
			amps = synth.at(\harm_array).cutoff(cutoff_n_val);
			synth.at(\harm_buffer).sine2(
				synth.at(\harm_array).ramp(1.0, 1.0), amps
			);
			~gui_draw_amps.value(window, configs, amps);
		}
	});
	top_offset = ~gui_offset_slider.value(top_offset, configs);
	cutoff_n_val_label = ~gui_place_val_label.value(
		window, configs, position, top_offset
	);
	cutoff_n_val_label.string_(round(cutoff_n_val)).align_(\center);
	cutoff_n_osc = OSCFunc({
		arg msg;
		{ cutoff_n_slider.valueAction = msg[1]; }.defer;
	}, osc_paths.at(\cutoff_n));
	cutoff_n_slider.onClose = { cutoff_n_osc.free; };

	position = position + 1;

	// SHELF
	top_offset = top;
	shelf_button = ~gui_place_button.value(
		window, configs, position, top_offset, "S"
	);
	shelf_button.action_({
		arg obj;
		switch (obj.value,
			0, {
				synth.at(\harm_buffer).sine1(0!configs.at(\n_partials));
				~gui_draw_amps.value(
					window, configs, 0!configs.at(\n_partials)
				);
			}, 1, {
				var amps;
				[ramp_button, decay_button, geom_button, formant_button,
				 teeth_button, cutoff_button].do({
					 arg btn; btn.value_(0);
				});
				amps = synth.at(\harm_array).shelf(
					shelf_start_val, shelf_end_val, shelf_slevel_val,
					shelf_elevel_val
				);
				synth.at(\harm_buffer).sine2(
					synth.at(\harm_array).ramp(1.0, 1.0), amps
				);
				~gui_draw_amps.value(window, configs, amps);
			}
		)
	});

	top_offset = top;
	top_offset = ~gui_offset_button.value(top, configs);
	shelf_start_label = ~gui_place_label.value(
		window, configs, position, top_offset, "start"
	);
	top_offset = ~gui_offset_label.value(top_offset, configs);
	shelf_start_slider = ~gui_place_slider.value(
		window, configs, position, top_offset
	);
	shelf_start_slider.value_(shelf_start_val.linlin(
		shelf_start_min, shelf_start_max, 0.0, 1.0)
	);
	shelf_start_slider.action_({
		arg obj;
		shelf_start_val = round(obj.value.linlin(
			0.0, 1.0, shelf_start_min, shelf_start_max)
		);
		shelf_start_val_label.string_(shelf_start_val);
		if (shelf_button.value == 1) {
			var amps;
			amps = synth.at(\harm_array).shelf(
				shelf_start_val, shelf_end_val, shelf_slevel_val,
				shelf_elevel_val
			);
			synth.at(\harm_buffer).sine2(
				synth.at(\harm_array).ramp(1.0, 1.0), amps
			);
			~gui_draw_amps.value(window, configs, amps);
		}
	});
	top_offset = ~gui_offset_slider.value(top_offset, configs);
	shelf_start_val_label = ~gui_place_val_label.value(
		window, configs, position, top_offset
	);
	shelf_start_val_label.string_(round(shelf_start_val)).align_(\center);
	shelf_start_osc = OSCFunc({
		arg msg;
		{ shelf_start_slider.valueAction = msg[1]; }.defer;
	}, osc_paths.at(\shelf_start));

	position = position + 1;

	top_offset = top;
	top_offset = ~gui_offset_button.value(top, configs);
	shelf_end_label = ~gui_place_label.value(
		window, configs, position, top_offset, "end"
	);
	top_offset = ~gui_offset_label.value(top_offset, configs);
	shelf_end_slider = ~gui_place_slider.value(
		window, configs, position, top_offset
	);
	shelf_end_slider.value_(shelf_end_val.linlin(
		shelf_end_min, shelf_end_max, 0.0, 1.0)
	);
	shelf_end_slider.action_({
		arg obj;
		shelf_end_val = round(obj.value.linlin(
			0.0, 1.0, shelf_end_min, shelf_end_max)
		);
		shelf_end_val_label.string_(shelf_end_val);
		if (shelf_button.value == 1) {
			var amps;
			amps = synth.at(\harm_array).shelf(
				shelf_start_val, shelf_end_val, shelf_slevel_val,
				shelf_elevel_val
			);
			synth.at(\harm_buffer).sine2(
				synth.at(\harm_array).ramp(1.0, 1.0), amps
			);
			~gui_draw_amps.value(window, configs, amps);
		}
	});
	top_offset = ~gui_offset_slider.value(top_offset, configs);
	shelf_end_val_label = ~gui_place_val_label.value(
		window, configs, position, top_offset
	);
	shelf_end_val_label.string_(round(shelf_end_val)).align_(\center);
	shelf_end_osc = OSCFunc({
		arg msg;
		{ shelf_end_slider.valueAction = msg[1]; }.defer;
	}, osc_paths.at(\shelf_end));

	position = position + 1;

	top_offset = top;
	top_offset = ~gui_offset_button.value(top, configs);
	shelf_slevel_label = ~gui_place_label.value(
		window, configs, position, top_offset, "slvl"
	);
	top_offset = ~gui_offset_label.value(top_offset, configs);
	shelf_slevel_slider = ~gui_place_slider.value(
		window, configs, position, top_offset
	);
	shelf_slevel_slider.value_(shelf_slevel_val.linlin(
		shelf_slevel_min, shelf_slevel_max, 0.0, 1.0)
	);
	shelf_slevel_slider.action_({
		arg obj;
		shelf_slevel_val = obj.value.linlin(
			0.0, 1.0, shelf_slevel_min, shelf_slevel_max
		);
		shelf_slevel_val_label.string_(shelf_slevel_val.asStringPrec(2));
		if (shelf_button.value == 1) {
			var amps;
			amps = synth.at(\harm_array).shelf(
				shelf_start_val, shelf_end_val, shelf_slevel_val,
				shelf_elevel_val
			);
			synth.at(\harm_buffer).sine2(
				synth.at(\harm_array).ramp(1.0, 1.0), amps
			);
			~gui_draw_amps.value(window, configs, amps);
		}
	});
	top_offset = ~gui_offset_slider.value(top_offset, configs);
	shelf_slevel_val_label = ~gui_place_val_label.value(
		window, configs, position, top_offset
	);
	shelf_slevel_val_label.string_(round(shelf_slevel_val)).align_(\center);
	shelf_slevel_osc = OSCFunc({
		arg msg;
		{ shelf_slevel_slider.valueAction = msg[1]; }.defer;
	}, osc_paths.at(\shelf_slevel));

	position = position + 1;

	top_offset = top;
	top_offset = ~gui_offset_button.value(top, configs);
	shelf_elevel_label = ~gui_place_label.value(
		window, configs, position, top_offset, "elvl"
	);
	top_offset = ~gui_offset_label.value(top_offset, configs);
	shelf_elevel_slider = ~gui_place_slider.value(
		window, configs, position, top_offset
	);
	shelf_elevel_slider.value_(shelf_elevel_val.linlin(
		shelf_elevel_min, shelf_elevel_max, 0.0, 1.0)
	);
	shelf_elevel_slider.action_({
		arg obj;
		shelf_elevel_val = obj.value.linlin(
			0.0, 1.0, shelf_elevel_min, shelf_elevel_max
		);
		shelf_elevel_val_label.string_(shelf_elevel_val.asStringPrec(2));
		if (shelf_button.value == 1) {
			var amps;
			amps = synth.at(\harm_array).shelf(
				shelf_start_val, shelf_end_val, shelf_slevel_val,
				shelf_elevel_val
			);
			synth.at(\harm_buffer).sine2(
				synth.at(\harm_array).ramp(1.0, 1.0), amps
			);
			~gui_draw_amps.value(window, configs, amps);
		}
	});
	top_offset = ~gui_offset_slider.value(top_offset, configs);
	shelf_elevel_val_label = ~gui_place_val_label.value(
		window, configs, position, top_offset
	);
	shelf_elevel_val_label.string_(
		shelf_elevel_val.asStringPrec(2)
	).align_(\center);
	shelf_elevel_osc = OSCFunc({
		arg msg;
		{ shelf_elevel_slider.valueAction = msg[1]; }.defer;
	}, osc_paths.at(\shelf_elevel));
	shelf_start_slider.onClose = {
		shelf_start_osc.free;
		shelf_end_osc.free;
		shelf_slevel_osc.free;
		shelf_elevel_osc.free;
	};

	position = position + 1;
};

~gui_reverb_ctrl = {
	arg window, top, position, configs, synth, osc_paths,
		mix_val=0.6, room_val=0.6, damp_val=0.5;
	var mix_label, mix_slider, mix_val_label, mix_osc,
	    room_label, room_slider, room_val_label, room_osc,
		damp_label, damp_slider, damp_val_label, damp_osc,
		top_offset;

	synth.at(\oscillator).set(\mix, mix_val);
	synth.at(\oscillator).set(\room, room_val);
	synth.at(\oscillator).set(\damp, damp_val);

	top_offset = ~gui_offset_button.value(top, configs);
	mix_label = ~gui_place_label.value(
		window, configs, position, top_offset, "reverb"
	);
	top_offset = ~gui_offset_label.value(top_offset, configs);
	mix_slider = ~gui_place_slider.value(
		window, configs, position, top_offset
	);
	mix_slider.value_(mix_val);
	mix_slider.action_({
		arg obj;
		mix_val = obj.value;
		mix_val_label.string_(mix_val.asStringPrec(2));
		synth.at(\oscillator).set(\mix, mix_val);
	});
	top_offset = ~gui_offset_slider.value(top_offset, configs);
	mix_val_label = ~gui_place_val_label.value(
		window, configs, position, top_offset
	);
	mix_val_label.string_(mix_val.asStringPrec(2)).align_(\center);
	mix_osc = OSCFunc({
		arg msg;
		{ mix_slider.valueAction = msg[1] }.defer;
	}, osc_paths.at(\verb_mix));

	position = position + 1;

	top_offset = ~gui_offset_button.value(top, configs);
	room_label = ~gui_place_label.value(
		window, configs, position, top_offset, "room"
	);
	top_offset = ~gui_offset_label.value(top_offset, configs);
	room_slider = ~gui_place_slider.value(
		window, configs, position, top_offset
	);
	room_slider.value_(room_val);
	room_slider.action_({
		arg obj;
		room_val = obj.value;
		room_val_label.string_(room_val.asStringPrec(2));
		synth.at(\oscillator).set(\room, room_val);
	});
	top_offset = ~gui_offset_slider.value(top_offset, configs);
	room_val_label = ~gui_place_val_label.value(
		window, configs, position, top_offset
	);
	room_val_label.string_(room_val.asStringPrec(2)).align_(\center);
	room_osc = OSCFunc({
		arg msg;
		{ room_slider.valueAction = msg[1] }.defer;
	}, osc_paths.at(\verb_room));

	position = position + 1;

	top_offset = ~gui_offset_button.value(top, configs);
	damp_label = ~gui_place_label.value(
		window, configs, position, top_offset, "damp"
	);
	top_offset = ~gui_offset_label.value(top_offset, configs);
	damp_slider = ~gui_place_slider.value(
		window, configs, position, top_offset
	);
	damp_slider.value_(damp_val);
	damp_slider.action_({
		arg obj;
		damp_val = obj.value;
		damp_val_label.string_(damp_val.asStringPrec(2));
		synth.at(\oscillator).set(\damp, damp_val);
	});
	top_offset = ~gui_offset_slider.value(top_offset, configs);
	damp_val_label = ~gui_place_val_label.value(
		window, configs, position, top_offset
	);
	damp_val_label.string_(damp_val.asStringPrec(2)).align_(\center);
	damp_osc = OSCFunc({
		arg msg;
		{ damp_slider.valueAction = msg[1] }.defer;
	}, osc_paths.at(\verb_damp));
	mix_slider.onClose = {
		mix_osc.free;
		room_osc.free;
		damp_osc.free;
	};

	position = position + 1;
};
)
