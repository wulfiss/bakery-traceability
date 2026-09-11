<script lang="ts">
	import { resolve } from '$app/paths';
	import type { ActionData } from './$types';

	let { form }: { form: ActionData } = $props();

	const values = form?.values ?? {
		orderNumber: '',
		customerName: '',
		requestedDate: '',
		deliveryTime: '',
		notes: ''
	};
</script>

<main class="page">
	<h1>Nuevo pedido</h1>

	{#if form?.error}
		<p class="error" role="alert">{form.error}</p>
	{/if}

	<form method="POST" action={resolve('/admin/external-orders/new?/create')} class="order-form">
		<label for="order_number">N° pedido</label>
		<input
			type="text"
			id="order_number"
			name="order_number"
			value={values.orderNumber}
			required
			autocomplete="off"
		/>

		<label for="customer_name">Cliente</label>
		<input
			type="text"
			id="customer_name"
			name="customer_name"
			value={values.customerName}
			required
			autocomplete="off"
		/>

		<label for="requested_date">Fecha requerida</label>
		<input
			type="date"
			id="requested_date"
			name="requested_date"
			value={values.requestedDate}
			required
		/>

		<label for="delivery_time">Hora de entrega (opcional)</label>
		<input type="time" id="delivery_time" name="delivery_time" value={values.deliveryTime} />

		<label for="notes">Observaciones (opcional)</label>
		<textarea id="notes" name="notes" rows="3">{values.notes}</textarea>

		<button type="submit" class="submit-btn">CREAR PEDIDO</button>
	</form>
</main>

<style>
	.page {
		display: block;
		width: 100%;
		max-width: var(--content-max);
		margin: 0 auto;
	}

	.error {
		color: var(--color-danger);
		font-weight: 700;
	}

	.order-form {
		display: flex;
		flex-direction: column;
	}

	textarea {
		resize: vertical;
		min-height: 80px;
	}

	.submit-btn {
		margin-top: 8px;
	}
</style>
