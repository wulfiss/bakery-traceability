<script lang="ts">
  import type { ActionData, PageData } from './$types'

  let { data, form }: { data: PageData; form: ActionData } = $props()
</script>

<div class="login-card">
  <h1>Trazabilidad de Panadería</h1>

  {#if form?.error}
    <p class="error" role="alert">{form.error}</p>
  {/if}

  <form method="POST">
    <label for="email">Correo</label>
    <input
      id="email"
      name="email"
      type="email"
      autocomplete="email"
      value={form?.email ?? ''}
      required
    />

    <label for="password">Contraseña</label>
    <input id="password" name="password" type="password" autocomplete="current-password" required />

    <button type="submit">INGRESAR</button>
  </form>
</div>

<style>
  .login-card {
    width: 100%;
    max-width: 420px;
    margin: 0 auto;
    padding: 24px 16px;
    box-sizing: border-box;
  }

  h1 {
    font-size: 1.375rem;
    text-align: center;
    margin-bottom: 24px;
  }

  form {
    display: flex;
    flex-direction: column;
    gap: 12px;
  }

  label {
    font-size: 0.9375rem;
    font-weight: 600;
  }

  input {
    width: 100%;
    padding: 10px 12px;
    font-size: 1rem;
    border: 1px solid #767676;
    border-radius: 8px;
    box-sizing: border-box;
  }

  button {
    width: 100%;
    padding: 12px;
    font-size: 1rem;
    font-weight: 700;
    letter-spacing: 0.05em;
    color: #ffffff;
    background-color: #ff3e00;
    border: none;
    border-radius: 8px;
    cursor: pointer;
  }

  button:active {
    transform: translateY(1px);
  }

  .error {
    color: #b00020;
    font-size: 0.9375rem;
    text-align: center;
    margin: 0 0 8px;
  }
</style>
