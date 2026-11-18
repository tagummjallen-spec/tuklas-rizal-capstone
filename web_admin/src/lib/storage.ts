import { supabase } from './supabase';

export const TOURISM_BUCKET = 'tourism-media';

/** Where the gallery picker puts files. */
export type UploadFolder = 'events' | 'pois';

const EXTENSION_BY_TYPE: Record<string, string> = {
  'image/jpeg': 'jpg',
  'image/png': 'png',
  'image/webp': 'webp',
  'image/gif': 'gif',
};

function extensionFor(file: File): string {
  const fromName = file.name.split('.').pop()?.toLowerCase();
  if (fromName && ['jpg', 'jpeg', 'png', 'webp', 'gif'].includes(fromName)) {
    return fromName === 'jpeg' ? 'jpg' : fromName;
  }
  return EXTENSION_BY_TYPE[file.type] ?? 'jpg';
}

/**
 * Upload a gallery photo to the public `tourism-media` bucket and return its
 * public URL, ready to be saved in `events.image_url` / `pois_logistics.image_url`.
 */
export async function uploadTourismImage(
  file: File,
  folder: UploadFolder,
): Promise<string> {
  if (!file.type.startsWith('image/')) {
    throw new Error('Please choose an image file (JPEG, PNG, WebP or GIF).');
  }
  if (file.size > 5 * 1024 * 1024) {
    throw new Error('Images must be 5 MB or smaller.');
  }

  const id =
    typeof crypto !== 'undefined' && 'randomUUID' in crypto
      ? crypto.randomUUID()
      : `${Date.now()}-${Math.random().toString(36).slice(2, 10)}`;
  const path = `${folder}/${id}.${extensionFor(file)}`;

  const { error } = await supabase.storage
    .from(TOURISM_BUCKET)
    .upload(path, file, {
      cacheControl: '3600',
      upsert: false,
      contentType: file.type || 'image/jpeg',
    });

  if (error) {
    throw new Error(
      error.message.includes('policy') || error.message.includes('row-level')
        ? 'Upload blocked by storage policy. Run supabase/storage_policies.sql and sign in with an LGU account.'
        : error.message,
    );
  }

  const { data } = supabase.storage.from(TOURISM_BUCKET).getPublicUrl(path);
  return data.publicUrl;
}
