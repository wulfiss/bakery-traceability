export type Json =
  | string
  | number
  | boolean
  | null
  | { [key: string]: Json | undefined }
  | Json[]

export type Database = {
  graphql_public: {
    Tables: {
      [_ in never]: never
    }
    Views: {
      [_ in never]: never
    }
    Functions: {
      graphql: {
        Args: {
          extensions?: Json
          operationName?: string
          query?: string
          variables?: Json
        }
        Returns: Json
      }
    }
    Enums: {
      [_ in never]: never
    }
    CompositeTypes: {
      [_ in never]: never
    }
  }
  public: {
    Tables: {
      batch_materials: {
        Row: {
          batch_id: string
          created_at: string
          id: string
          material_lot_id: string
          raw_material_id: string
          recipe_quantity: number | null
          recipe_unit: string | null
        }
        Insert: {
          batch_id: string
          created_at?: string
          id?: string
          material_lot_id: string
          raw_material_id: string
          recipe_quantity?: number | null
          recipe_unit?: string | null
        }
        Update: {
          batch_id?: string
          created_at?: string
          id?: string
          material_lot_id?: string
          raw_material_id?: string
          recipe_quantity?: number | null
          recipe_unit?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "batch_materials_batch_id_fkey"
            columns: ["batch_id"]
            isOneToOne: false
            referencedRelation: "production_batches"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "batch_materials_material_lot_id_fkey"
            columns: ["material_lot_id"]
            isOneToOne: false
            referencedRelation: "material_lots"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "batch_materials_raw_material_id_fkey"
            columns: ["raw_material_id"]
            isOneToOne: false
            referencedRelation: "raw_materials"
            referencedColumns: ["id"]
          },
        ]
      }
      batch_outputs: {
        Row: {
          batch_id: string
          created_at: string
          id: string
          product_id: string
          quantity: number
          unit: string
        }
        Insert: {
          batch_id: string
          created_at?: string
          id?: string
          product_id: string
          quantity: number
          unit: string
        }
        Update: {
          batch_id?: string
          created_at?: string
          id?: string
          product_id?: string
          quantity?: number
          unit?: string
        }
        Relationships: [
          {
            foreignKeyName: "batch_outputs_batch_id_fkey"
            columns: ["batch_id"]
            isOneToOne: false
            referencedRelation: "production_batches"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "batch_outputs_product_id_fkey"
            columns: ["product_id"]
            isOneToOne: false
            referencedRelation: "products"
            referencedColumns: ["id"]
          },
        ]
      }
      batch_requests: {
        Row: {
          allocated_quantity: number | null
          batch_id: string
          created_at: string
          id: string
          production_request_id: string
        }
        Insert: {
          allocated_quantity?: number | null
          batch_id: string
          created_at?: string
          id?: string
          production_request_id: string
        }
        Update: {
          allocated_quantity?: number | null
          batch_id?: string
          created_at?: string
          id?: string
          production_request_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "batch_requests_batch_id_fkey"
            columns: ["batch_id"]
            isOneToOne: false
            referencedRelation: "production_batches"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "batch_requests_production_request_id_fkey"
            columns: ["production_request_id"]
            isOneToOne: false
            referencedRelation: "production_requests"
            referencedColumns: ["id"]
          },
        ]
      }
      brands: {
        Row: {
          active: boolean
          created_at: string
          id: string
          name: string
          updated_at: string
        }
        Insert: {
          active?: boolean
          created_at?: string
          id?: string
          name: string
          updated_at?: string
        }
        Update: {
          active?: boolean
          created_at?: string
          id?: string
          name?: string
          updated_at?: string
        }
        Relationships: []
      }
      external_order_items: {
        Row: {
          created_at: string
          external_order_id: string
          id: string
          notes: string | null
          product_id: string
          quantity: number
          shift_code: string
          unit: string
        }
        Insert: {
          created_at?: string
          external_order_id: string
          id?: string
          notes?: string | null
          product_id: string
          quantity: number
          shift_code: string
          unit: string
        }
        Update: {
          created_at?: string
          external_order_id?: string
          id?: string
          notes?: string | null
          product_id?: string
          quantity?: number
          shift_code?: string
          unit?: string
        }
        Relationships: [
          {
            foreignKeyName: "external_order_items_external_order_id_fkey"
            columns: ["external_order_id"]
            isOneToOne: false
            referencedRelation: "external_orders"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "external_order_items_product_id_fkey"
            columns: ["product_id"]
            isOneToOne: false
            referencedRelation: "products"
            referencedColumns: ["id"]
          },
        ]
      }
      external_orders: {
        Row: {
          created_at: string
          created_by: string | null
          customer_name: string
          delivery_time: string | null
          id: string
          notes: string | null
          order_number: string
          requested_date: string
          status: string
          updated_at: string
        }
        Insert: {
          created_at?: string
          created_by?: string | null
          customer_name: string
          delivery_time?: string | null
          id?: string
          notes?: string | null
          order_number: string
          requested_date: string
          status: string
          updated_at?: string
        }
        Update: {
          created_at?: string
          created_by?: string | null
          customer_name?: string
          delivery_time?: string | null
          id?: string
          notes?: string | null
          order_number?: string
          requested_date?: string
          status?: string
          updated_at?: string
        }
        Relationships: []
      }
      material_lots: {
        Row: {
          brand_id: string
          closed_at: string | null
          created_at: string
          created_by: string | null
          expiry_date: string | null
          id: string
          is_current: boolean
          opened_at: string | null
          raw_material_id: string
          received_at: string | null
          status: string
          supplier_lot: string
        }
        Insert: {
          brand_id: string
          closed_at?: string | null
          created_at?: string
          created_by?: string | null
          expiry_date?: string | null
          id?: string
          is_current?: boolean
          opened_at?: string | null
          raw_material_id: string
          received_at?: string | null
          status: string
          supplier_lot: string
        }
        Update: {
          brand_id?: string
          closed_at?: string | null
          created_at?: string
          created_by?: string | null
          expiry_date?: string | null
          id?: string
          is_current?: boolean
          opened_at?: string | null
          raw_material_id?: string
          received_at?: string | null
          status?: string
          supplier_lot?: string
        }
        Relationships: [
          {
            foreignKeyName: "material_lots_brand_id_fkey"
            columns: ["brand_id"]
            isOneToOne: false
            referencedRelation: "brands"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "material_lots_raw_material_id_fkey"
            columns: ["raw_material_id"]
            isOneToOne: false
            referencedRelation: "raw_materials"
            referencedColumns: ["id"]
          },
        ]
      }
      parent_batch_inputs: {
        Row: {
          child_batch_id: string
          created_at: string
          id: string
          parent_batch_output_id: string
          quantity: number | null
          unit: string | null
        }
        Insert: {
          child_batch_id: string
          created_at?: string
          id?: string
          parent_batch_output_id: string
          quantity?: number | null
          unit?: string | null
        }
        Update: {
          child_batch_id?: string
          created_at?: string
          id?: string
          parent_batch_output_id?: string
          quantity?: number | null
          unit?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "parent_batch_inputs_child_batch_id_fkey"
            columns: ["child_batch_id"]
            isOneToOne: false
            referencedRelation: "production_batches"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "parent_batch_inputs_parent_batch_output_id_fkey"
            columns: ["parent_batch_output_id"]
            isOneToOne: false
            referencedRelation: "batch_outputs"
            referencedColumns: ["id"]
          },
        ]
      }
      production_batches: {
        Row: {
          batch_code: string
          created_at: string
          finished_at: string | null
          finished_by: string | null
          id: string
          notes: string | null
          production_day_id: string
          recipe_version_id: string
          shift_code: string
          started_at: string
          started_by: string
          status: string
        }
        Insert: {
          batch_code: string
          created_at?: string
          finished_at?: string | null
          finished_by?: string | null
          id?: string
          notes?: string | null
          production_day_id: string
          recipe_version_id: string
          shift_code: string
          started_at: string
          started_by: string
          status: string
        }
        Update: {
          batch_code?: string
          created_at?: string
          finished_at?: string | null
          finished_by?: string | null
          id?: string
          notes?: string | null
          production_day_id?: string
          recipe_version_id?: string
          shift_code?: string
          started_at?: string
          started_by?: string
          status?: string
        }
        Relationships: [
          {
            foreignKeyName: "production_batches_production_day_id_fkey"
            columns: ["production_day_id"]
            isOneToOne: false
            referencedRelation: "production_days"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "production_batches_recipe_version_id_fkey"
            columns: ["recipe_version_id"]
            isOneToOne: false
            referencedRelation: "recipe_versions"
            referencedColumns: ["id"]
          },
        ]
      }
      production_days: {
        Row: {
          closed_at: string | null
          closed_by: string | null
          created_at: string
          id: string
          opened_at: string | null
          opened_by: string | null
          production_date: string
          status: string
        }
        Insert: {
          closed_at?: string | null
          closed_by?: string | null
          created_at?: string
          id?: string
          opened_at?: string | null
          opened_by?: string | null
          production_date: string
          status: string
        }
        Update: {
          closed_at?: string | null
          closed_by?: string | null
          created_at?: string
          id?: string
          opened_at?: string | null
          opened_by?: string | null
          production_date?: string
          status?: string
        }
        Relationships: []
      }
      production_plan_items: {
        Row: {
          active: boolean
          created_at: string
          id: string
          planned_quantity: number
          product_id: string
          shift_code: string
          sort_order: number
          unit: string
          updated_at: string
          weekday: number
        }
        Insert: {
          active?: boolean
          created_at?: string
          id?: string
          planned_quantity: number
          product_id: string
          shift_code: string
          sort_order?: number
          unit: string
          updated_at?: string
          weekday: number
        }
        Update: {
          active?: boolean
          created_at?: string
          id?: string
          planned_quantity?: number
          product_id?: string
          shift_code?: string
          sort_order?: number
          unit?: string
          updated_at?: string
          weekday?: number
        }
        Relationships: [
          {
            foreignKeyName: "production_plan_items_product_id_fkey"
            columns: ["product_id"]
            isOneToOne: false
            referencedRelation: "products"
            referencedColumns: ["id"]
          },
        ]
      }
      production_requests: {
        Row: {
          created_at: string
          created_by: string | null
          external_order_item_id: string | null
          id: string
          product_id: string
          production_day_id: string
          reason_code: string | null
          reason_note: string | null
          requested_quantity: number
          shift_code: string
          source_type: string
          status: string
          unit: string
        }
        Insert: {
          created_at?: string
          created_by?: string | null
          external_order_item_id?: string | null
          id?: string
          product_id: string
          production_day_id: string
          reason_code?: string | null
          reason_note?: string | null
          requested_quantity: number
          shift_code: string
          source_type: string
          status: string
          unit: string
        }
        Update: {
          created_at?: string
          created_by?: string | null
          external_order_item_id?: string | null
          id?: string
          product_id?: string
          production_day_id?: string
          reason_code?: string | null
          reason_note?: string | null
          requested_quantity?: number
          shift_code?: string
          source_type?: string
          status?: string
          unit?: string
        }
        Relationships: [
          {
            foreignKeyName: "production_requests_external_order_item_id_fkey"
            columns: ["external_order_item_id"]
            isOneToOne: false
            referencedRelation: "external_order_items"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "production_requests_product_id_fkey"
            columns: ["product_id"]
            isOneToOne: false
            referencedRelation: "products"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "production_requests_production_day_id_fkey"
            columns: ["production_day_id"]
            isOneToOne: false
            referencedRelation: "production_days"
            referencedColumns: ["id"]
          },
        ]
      }
      products: {
        Row: {
          active: boolean
          created_at: string
          default_shift_code: string
          default_unit: string
          id: string
          name: string
          updated_at: string
        }
        Insert: {
          active?: boolean
          created_at?: string
          default_shift_code: string
          default_unit: string
          id?: string
          name: string
          updated_at?: string
        }
        Update: {
          active?: boolean
          created_at?: string
          default_shift_code?: string
          default_unit?: string
          id?: string
          name?: string
          updated_at?: string
        }
        Relationships: []
      }
      profiles: {
        Row: {
          active: boolean
          created_at: string
          full_name: string
          id: string
          role: string
          updated_at: string
        }
        Insert: {
          active?: boolean
          created_at?: string
          full_name: string
          id: string
          role: string
          updated_at?: string
        }
        Update: {
          active?: boolean
          created_at?: string
          full_name?: string
          id?: string
          role?: string
          updated_at?: string
        }
        Relationships: []
      }
      raw_material_brands: {
        Row: {
          active: boolean
          brand_id: string
          created_at: string
          id: string
          raw_material_id: string
        }
        Insert: {
          active?: boolean
          brand_id: string
          created_at?: string
          id?: string
          raw_material_id: string
        }
        Update: {
          active?: boolean
          brand_id?: string
          created_at?: string
          id?: string
          raw_material_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "raw_material_brands_brand_id_fkey"
            columns: ["brand_id"]
            isOneToOne: false
            referencedRelation: "brands"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "raw_material_brands_raw_material_id_fkey"
            columns: ["raw_material_id"]
            isOneToOne: false
            referencedRelation: "raw_materials"
            referencedColumns: ["id"]
          },
        ]
      }
      raw_materials: {
        Row: {
          active: boolean
          created_at: string
          default_unit: string
          id: string
          name: string
          updated_at: string
        }
        Insert: {
          active?: boolean
          created_at?: string
          default_unit: string
          id?: string
          name: string
          updated_at?: string
        }
        Update: {
          active?: boolean
          created_at?: string
          default_unit?: string
          id?: string
          name?: string
          updated_at?: string
        }
        Relationships: []
      }
      recipe_ingredients: {
        Row: {
          created_at: string
          id: string
          optional: boolean
          quantity: number
          raw_material_id: string
          recipe_version_id: string
          sort_order: number
          unit: string
        }
        Insert: {
          created_at?: string
          id?: string
          optional?: boolean
          quantity: number
          raw_material_id: string
          recipe_version_id: string
          sort_order?: number
          unit: string
        }
        Update: {
          created_at?: string
          id?: string
          optional?: boolean
          quantity?: number
          raw_material_id?: string
          recipe_version_id?: string
          sort_order?: number
          unit?: string
        }
        Relationships: [
          {
            foreignKeyName: "recipe_ingredients_raw_material_id_fkey"
            columns: ["raw_material_id"]
            isOneToOne: false
            referencedRelation: "raw_materials"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "recipe_ingredients_recipe_version_id_fkey"
            columns: ["recipe_version_id"]
            isOneToOne: false
            referencedRelation: "recipe_versions"
            referencedColumns: ["id"]
          },
        ]
      }
      recipe_product_inputs: {
        Row: {
          created_at: string
          id: string
          quantity: number | null
          recipe_version_id: string
          required: boolean
          source_product_id: string
          unit: string | null
        }
        Insert: {
          created_at?: string
          id?: string
          quantity?: number | null
          recipe_version_id: string
          required?: boolean
          source_product_id: string
          unit?: string | null
        }
        Update: {
          created_at?: string
          id?: string
          quantity?: number | null
          recipe_version_id?: string
          required?: boolean
          source_product_id?: string
          unit?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "recipe_product_inputs_recipe_version_id_fkey"
            columns: ["recipe_version_id"]
            isOneToOne: false
            referencedRelation: "recipe_versions"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "recipe_product_inputs_source_product_id_fkey"
            columns: ["source_product_id"]
            isOneToOne: false
            referencedRelation: "products"
            referencedColumns: ["id"]
          },
        ]
      }
      recipe_products: {
        Row: {
          created_at: string
          id: string
          product_id: string
          recipe_id: string
          sort_order: number
        }
        Insert: {
          created_at?: string
          id?: string
          product_id: string
          recipe_id: string
          sort_order?: number
        }
        Update: {
          created_at?: string
          id?: string
          product_id?: string
          recipe_id?: string
          sort_order?: number
        }
        Relationships: [
          {
            foreignKeyName: "recipe_products_product_id_fkey"
            columns: ["product_id"]
            isOneToOne: false
            referencedRelation: "products"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "recipe_products_recipe_id_fkey"
            columns: ["recipe_id"]
            isOneToOne: false
            referencedRelation: "recipes"
            referencedColumns: ["id"]
          },
        ]
      }
      recipe_versions: {
        Row: {
          created_at: string
          effective_from: string | null
          effective_to: string | null
          id: string
          notes: string | null
          recipe_id: string
          status: string
          version_number: number
        }
        Insert: {
          created_at?: string
          effective_from?: string | null
          effective_to?: string | null
          id?: string
          notes?: string | null
          recipe_id: string
          status: string
          version_number: number
        }
        Update: {
          created_at?: string
          effective_from?: string | null
          effective_to?: string | null
          id?: string
          notes?: string | null
          recipe_id?: string
          status?: string
          version_number?: number
        }
        Relationships: [
          {
            foreignKeyName: "recipe_versions_recipe_id_fkey"
            columns: ["recipe_id"]
            isOneToOne: false
            referencedRelation: "recipes"
            referencedColumns: ["id"]
          },
        ]
      }
      recipes: {
        Row: {
          active: boolean
          created_at: string
          id: string
          name: string
          updated_at: string
        }
        Insert: {
          active?: boolean
          created_at?: string
          id?: string
          name: string
          updated_at?: string
        }
        Update: {
          active?: boolean
          created_at?: string
          id?: string
          name?: string
          updated_at?: string
        }
        Relationships: []
      }
    }
    Views: {
      [_ in never]: never
    }
    Functions: {
      add_external_order_item: {
        Args: {
          p_external_order_id: string
          p_notes: string
          p_product_id: string
          p_quantity: number
          p_shift_code: string
          p_unit: string
        }
        Returns: string
      }
      change_current_material_lot: {
        Args: {
          p_brand_id: string
          p_expiry_date?: string
          p_raw_material_id: string
          p_supplier_lot: string
        }
        Returns: string
      }
      complete_production_batch: {
        Args: { p_actual_quantity: number; p_batch_id: string; p_unit: string }
        Returns: undefined
      }
      create_additional_production_request: {
        Args: {
          p_product_id: string
          p_production_day_id: string
          p_reason_code: string
          p_reason_note?: string
          p_requested_quantity: number
          p_shift_code: string
          p_unit: string
        }
        Returns: string
      }
      create_brand: { Args: { p_name: string }; Returns: string }
      create_external_order: {
        Args: {
          p_customer_name: string
          p_delivery_time: string
          p_notes: string
          p_order_number: string
          p_requested_date: string
        }
        Returns: string
      }
      create_raw_material: {
        Args: { p_default_unit: string; p_name: string }
        Returns: string
      }
      ensure_base_production_requests: {
        Args: { p_production_day_id: string }
        Returns: number
      }
      ensure_external_order_requests: {
        Args: { p_production_day_id: string }
        Returns: number
      }
      ensure_production_day: { Args: never; Returns: string }
      get_business_date: { Args: never; Returns: string }
      next_batch_code: {
        Args: { p_production_day_id: string; p_shift_code: string }
        Returns: string
      }
      set_brand_active: {
        Args: { p_active: boolean; p_id: string }
        Returns: string
      }
      set_raw_material_active: {
        Args: { p_active: boolean; p_id: string }
        Returns: string
      }
      start_production_batch: {
        Args: { p_production_request_id: string }
        Returns: Database["public"]["CompositeTypes"]["start_production_batch_result"]
        SetofOptions: {
          from: "*"
          to: "start_production_batch_result"
          isOneToOne: true
          isSetofReturn: false
        }
      }
      update_brand: { Args: { p_id: string; p_name: string }; Returns: string }
      update_raw_material: {
        Args: { p_default_unit: string; p_id: string; p_name: string }
        Returns: string
      }
    }
    Enums: {
      [_ in never]: never
    }
    CompositeTypes: {
      start_production_batch_result: {
        batch_id: string | null
        batch_code: string | null
      }
    }
  }
}

type DatabaseWithoutInternals = Omit<Database, "__InternalSupabase">

type DefaultSchema = DatabaseWithoutInternals[Extract<keyof Database, "public">]

export type Tables<
  DefaultSchemaTableNameOrOptions extends
    | keyof (DefaultSchema["Tables"] & DefaultSchema["Views"])
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends (DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof (DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"] &
        DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Views"])
    : never) = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? (DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"] &
      DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Views"])[TableName] extends {
      Row: infer R
    }
    ? R
    : never
  : DefaultSchemaTableNameOrOptions extends keyof (DefaultSchema["Tables"] &
        DefaultSchema["Views"])
    ? (DefaultSchema["Tables"] &
        DefaultSchema["Views"])[DefaultSchemaTableNameOrOptions] extends {
        Row: infer R
      }
      ? R
      : never
    : never

export type TablesInsert<
  DefaultSchemaTableNameOrOptions extends
    | keyof DefaultSchema["Tables"]
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends (DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"]
    : never) = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"][TableName] extends {
      Insert: infer I
    }
    ? I
    : never
  : DefaultSchemaTableNameOrOptions extends keyof DefaultSchema["Tables"]
    ? DefaultSchema["Tables"][DefaultSchemaTableNameOrOptions] extends {
        Insert: infer I
      }
      ? I
      : never
    : never

export type TablesUpdate<
  DefaultSchemaTableNameOrOptions extends
    | keyof DefaultSchema["Tables"]
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends (DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"]
    : never) = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"][TableName] extends {
      Update: infer U
    }
    ? U
    : never
  : DefaultSchemaTableNameOrOptions extends keyof DefaultSchema["Tables"]
    ? DefaultSchema["Tables"][DefaultSchemaTableNameOrOptions] extends {
        Update: infer U
      }
      ? U
      : never
    : never

export type Enums<
  DefaultSchemaEnumNameOrOptions extends
    | keyof DefaultSchema["Enums"]
    | { schema: keyof DatabaseWithoutInternals },
  EnumName extends (DefaultSchemaEnumNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaEnumNameOrOptions["schema"]]["Enums"]
    : never) = never,
> = DefaultSchemaEnumNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaEnumNameOrOptions["schema"]]["Enums"][EnumName]
  : DefaultSchemaEnumNameOrOptions extends keyof DefaultSchema["Enums"]
    ? DefaultSchema["Enums"][DefaultSchemaEnumNameOrOptions]
    : never

export type CompositeTypes<
  PublicCompositeTypeNameOrOptions extends
    | keyof DefaultSchema["CompositeTypes"]
    | { schema: keyof DatabaseWithoutInternals },
  CompositeTypeName extends (PublicCompositeTypeNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[PublicCompositeTypeNameOrOptions["schema"]]["CompositeTypes"]
    : never) = never,
> = PublicCompositeTypeNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[PublicCompositeTypeNameOrOptions["schema"]]["CompositeTypes"][CompositeTypeName]
  : PublicCompositeTypeNameOrOptions extends keyof DefaultSchema["CompositeTypes"]
    ? DefaultSchema["CompositeTypes"][PublicCompositeTypeNameOrOptions]
    : never

export const Constants = {
  graphql_public: {
    Enums: {},
  },
  public: {
    Enums: {},
  },
} as const

