/**
 * Types mirror the LIVE `public` schema verified against production PostgREST.
 * Never add a field that is not present on the live table — PostgREST rejects
 * unknown columns with PGRST204.
 */

export type RoleTier = 0 | 1 | 2 | 3 | 4;

/** public.users */
export interface UserProfile {
  id: string;
  email: string;
  full_name: string;
  avatar_url: string | null;
  role_tier: number;
  role_title: string | null;
  municipality_id: string | null;
  barangay_id: string | null;
  is_approved: boolean;
  created_at: string;
  updated_at: string;
}

/** public.municipalities */
export interface Municipality {
  id: string;
  name: string;
  slug: string;
  latitude: number | null;
  longitude: number | null;
  geofence_radius_meters: number | null;
  tourism_office_name: string | null;
  coordinator_contact_email: string | null;
  coordinator_contact_phone: string | null;
  tourism_office_address: string | null;
  visitor_priority_boost: number;
}

/** public.barangays */
export interface Barangay {
  id: string;
  municipality_id: string;
  name: string;
  latitude: number | null;
  longitude: number | null;
}

/** public.categories */
export interface Category {
  id: string;
  name: string;
  slug: string;
}

export type EventStatus = 'draft' | 'approved' | 'rejected';

/** public.events */
export interface EventRecord {
  id: string;
  municipality_id: string;
  barangay_id: string | null;
  category_id: string | null;
  title: string;
  description: string | null;
  venue_name: string | null;
  how_to_get_there: string | null;
  start_date: string;
  end_date: string;
  latitude: number | null;
  longitude: number | null;
  status: EventStatus;
  is_featured: boolean;
  promotion_weight: number;
  created_at: string;
}

/** public.pois_logistics */
export interface PoiRecord {
  id: string;
  municipality_id: string;
  barangay_id: string | null;
  category_id: string | null;
  name: string;
  description: string | null;
  poi_type: string | null;
  how_to_get_there: string | null;
  operating_hours: string | null;
  entrance_fee: string | null;
  latitude: number | null;
  longitude: number | null;
  is_promoted: boolean;
  created_at: string;
}

/** public.event_participation */
export interface EventParticipation {
  id: string;
  user_id: string;
  event_id: string;
  status: string;
  created_at: string;
}

export type InquiryStatus = 'open' | 'in_progress' | 'resolved';

/** public.coordinator_inquiries */
export interface CoordinatorInquiry {
  id: string;
  user_id: string;
  municipality_id: string;
  subject: string;
  message: string;
  coordinator_reply: string | null;
  status: InquiryStatus;
  created_at: string;
}

export const POI_TYPES = [
  'heritage_site',
  'unique_food',
  'destination',
  'restaurant',
  'logistics',
] as const;
