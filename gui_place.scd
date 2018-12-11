(
/* These funtions are helpers for placing the various GUI elements on the
main window. I've played around with the various QT Layouts and went with
this manual positioning in the end. Too many things to learn at once...
I'll focus on more efficient layouts on a future project.
*/

~gui_offset_button = {
	arg top, configs;
	top + configs.at(\button_height) + configs.at(\inner_margin);
};

~gui_offset_label = {
	arg top, configs;
	top + configs.at(\label_height) + configs.at(\inner_margin);
};

~gui_offset_slider = {
	arg top, configs;
	top + configs.at(\slider_height) + configs.at(\inner_margin);
};

~gui_offset_top_row = {
	arg top, configs;
	top = top + ~gui_offset_button.value(top, configs);
	top = top + ~gui_offset_label.value(top, configs);
	top = top + ~gui_offset_slider.value(top, configs);
	top = top + ~gui_offset_label.value(top, configs);
	top + configs.at(\inner_margin);
};

~gui_place_title = {
	arg window, configs, text="";
	var title, width;

	if (text == "") { text = "[ many sines summed various ways ]" };
	width = window.view.bounds.width;

	title = StaticText(
		window.view,
		Rect.new(
			configs.at(\window_margin),
			configs.at(\window_margin),
			width - (2 * configs.at(\window_margin)),
			configs.at(\title_height)
	));
	title.font_(configs.at(\title_font));
	title.stringColor_(configs.at(\title_color));
	title.string_(text).align_(\center);
	title;
};

~gui_place_button = {
	arg window, configs, position, top, text;
	var button, button_offset;

	button_offset = (
		(configs.at(\parameter_width) / 2) -
		(configs.at(\button_width) / 2)
	);

	button = Button.new(
		window.view,
		Rect.new(
			(
				configs.at(\window_margin) +
				(position * configs.at(\parameter_width)) +
				button_offset
			),
			top,
			configs.at(\button_width),
			configs.at(\button_height)
	));
	button.font_(configs.at(\button_font));
	button.states = [
		[
			text,
			configs.at(\button_font_color),
			configs.at(\button_back_color)
		],
		[
			text,
			configs.at(\button_active_font_color),
			configs.at(\button_active_back_color)
		]
	];
	button;
};

~gui_place_label = {
	arg window, configs, position, top, text;
	var label;

	label = StaticText.new(
		window.view,
		Rect.new(
			(
				configs.at(\window_margin) +
				(position * configs.at(\parameter_width))
			),
			top,
			configs.at(\label_width),
			configs.at(\label_height)
	));
	label.font_(configs.at(\main_font));
	label.stringColor_(configs.at(\main_font_color));
	label.string_(text).align_(\center);
	label;
};

~gui_place_slider = {
	arg window, configs, position, top;
	var slider, slider_offset;

	slider_offset = (
		(configs.at(\parameter_width) / 2) - (configs.at(\slider_width) / 2)
	);
	slider = Slider.new(
		window.view,
		Rect.new(
			(
				configs.at(\window_margin) +
				(position * configs.at(\parameter_width)) +
				slider_offset
			),
			top,
			configs.at(\slider_width),
			configs.at(\slider_height)
	));
	slider;
};

~gui_place_level = {
	arg window, configs, position, top;
	var level, level_offset;

	level_offset = (
			(configs.at(\parameter_width) / 2) - (configs.at(\level_width) / 2)
		);
	level = LevelIndicator.new(
		window.view,
		Rect.new(
			(
				configs.at(\window_margin) +
				(position * configs.at(\parameter_width)) +
				level_offset
			),
			top + 2,
			configs.at(\level_width),
			configs.at(\level_height)
	));
	level;
};

~gui_place_val_label = {
	arg window, configs, position, top;
	var val_label;

	val_label = StaticText.new(
		window.view,
		Rect.new(
			(
				configs.at(\window_margin) +
				(position * configs.at(\parameter_width))
			),
			top,
			configs.at(\label_width),
			configs.at(\label_height)
	));
	val_label.font_(configs.at(\main_font));
	val_label.stringColor_(configs.at(\main_font_color));
	val_label;
};

~gui_place_param_seperator = {
	// FIXME Only the last seperator appears. Use a matrix ?
	arg window, configs, position, top;
	var x, center_y, p1, p2;

	x = (
		position *
		configs.at(\parameter_width) +
		(configs.at(\parameter_width) / 2)
	);
	top = ~gui_offset_button.value(top, configs);
	top = ~gui_offset_label.value(top, configs);
	center_y = top + (configs.at(\slider_height) / 2);
	p1 = x@(center_y - 10);
	p2 = x@(center_y + 10);
	window.drawFunc_({
		Pen.line(p1, p2);
		Pen.stroke;
	});
};
)
