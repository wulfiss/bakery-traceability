<script lang="ts">
	import { resolve } from '$app/paths';
</script>

<main class="page">
	<h1>Administración</h1>

	<ul class="links">
		<li>
			<a href={resolve('/admin/external-orders')}>Pedidos externos</a>
		</li>
		<li>
			<a href={resolve('/admin/raw-materials')}>Materiales</a>
		</li>
		<li>
			<a href={resolve('/admin/brands')}>Marcas</a>
		</li>
		<li>
			<a href={resolve('/admin/products')}>Productos</a>
		</li>
		<li>
			<a href={resolve('/admin/recipes')}>Recetas</a>
		</li>
		<li>
			<a href={resolve('/admin/planning')}>Planificación</a>
		</li>
	</ul>
</main>

<style>
	.page {
		padding: 16px;
		width: 100%;
		max-width: var(--content-max);
		margin: 0 auto;
	}

	.links {
		list-style: none;
		margin: 0;
		padding: 0;
		display: flex;
		flex-direction: column;
		gap: 8px;
	}

	.links a {
		display: block;
		min-height: var(--touch-min);
		line-height: calc(var(--touch-min) - 2px);
		padding: 10px 14px;
		border: 1px solid var(--color-border);
		border-radius: var(--radius);
		background: var(--color-surface);
		text-decoration: none;
		font-weight: 700;
	}
</style>
