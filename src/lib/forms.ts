import type { SubmitFunction } from '@sveltejs/kit';

// Disable every button in the form while the enhanced action is in flight so a
// double tap cannot fire the same write twice. This SvelteKit build's `enhance`
// action only accepts a submit callback (no `in`/`disable` transition hook),
// so the guard lives here and the default enhanced behavior is restored with
// `update()`. The authoritative protection always remains server-side
// (row locks + status guards in the RPCs).
export const preventDoubleSubmit: SubmitFunction = ({ formElement }) => {
	const buttons = Array.from(formElement.querySelectorAll('button'));
	for (const button of buttons) button.disabled = true;
	return ({ update }) => {
		for (const button of buttons) button.disabled = false;
		return update();
	};
};
