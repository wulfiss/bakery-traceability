import type { PageServerLoad } from './$types';
import type { Database } from '$lib/types/database.types';

// Explicit row annotation: supabase-js 2.116 under TS 6 does not resolve the
// inferred select type in this toolchain (see AGENTS.md).
type ExternalOrderLite = Pick<
	Database['public']['Tables']['external_orders']['Row'],
	'id' | 'order_number' | 'customer_name' | 'requested_date' | 'status'
>;

export type OrderItem = {
	id: string;
	orderNumber: string;
	customerName: string;
	requestedDate: string;
	status: Database['public']['Tables']['external_orders']['Row']['status'];
};

export const load: PageServerLoad = async (event) => {
	const supabase = event.locals.supabase;

	// Read-only list. RLS (external_orders_select_active) limits rows to users
	// with an active profile. Most recent requested date first.
	const result = await supabase
		.from('external_orders')
		.select('id, order_number, customer_name, requested_date, status')
		.order('requested_date', { ascending: false })
		.order('order_number', { ascending: true });
	if (result.error) throw result.error;

	const orders: ExternalOrderLite[] = result.data ?? [];

	const items: OrderItem[] = orders.map((order) => ({
		id: order.id,
		orderNumber: order.order_number,
		customerName: order.customer_name,
		requestedDate: formatRequestedDate(order.requested_date),
		status: order.status
	}));

	return { orders: items };
};

// 'YYYY-MM-DD' (stored) -> 'DD/MM/YYYY' (UI display only).
function formatRequestedDate(value: string): string {
	const parts = value.split('-');
	if (parts.length !== 3) return value;
	return `${parts[2]}/${parts[1]}/${parts[0]}`;
}
