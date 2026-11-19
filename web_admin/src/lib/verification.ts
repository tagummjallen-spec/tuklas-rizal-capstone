import { describeError, supabase } from './supabase';

/** Private bucket provisioned by `supabase/admin_user_approvals.sql`. */
export const VERIFICATION_BUCKET = 'admin-verification-docs';
export const MAX_VERIFICATION_BYTES = 10 * 1024 * 1024;

/** True for PDF documents; images are previewed inline instead. */
export function isPdfPath(path: string): boolean {
  return /\.pdf($|\?)/i.test(path);
}

/** Filename shown in the inspector, without the storage folder prefix. */
export function docFileName(path: string): string {
  const cleaned = path.split('?')[0];
  const name = cleaned.split('/').pop() ?? cleaned;
  try {
    return decodeURIComponent(name);
  } catch {
    return name;
  }
}

/**
 * Resolves a stored verification path to a viewable URL.
 *
 * Entries already holding an absolute http(s) link (a Drive link pasted by the
 * applicant) are returned as-is; storage paths get a 1-hour signed URL.
 */
export async function resolveVerificationDoc(
  path: string,
): Promise<{ url: string | null; error: string | null }> {
  if (!path) return { url: null, error: 'Empty document reference.' };
  if (/^https?:\/\//i.test(path)) return { url: path, error: null };
  try {
    const { data, error } = await supabase.storage
      .from(VERIFICATION_BUCKET)
      .createSignedUrl(path, 3600);
    if (error) return { url: null, error: describeError(error) };
    return { url: data?.signedUrl ?? null, error: null };
  } catch (error) {
    return { url: null, error: describeError(error) };
  }
}

/**
 * Uploads one verification document into `<userId>/…` and returns its path.
 * Throws a readable Error on size/type/RLS failures.
 */
export async function uploadVerificationFile(
  file: File,
  userId: string,
): Promise<string> {
  if (!file) throw new Error('Choose a file to upload.');
  if (file.size === 0) throw new Error('That file is empty.');
  if (file.size > MAX_VERIFICATION_BYTES) {
    throw new Error('Each document must be 10 MB or smaller.');
  }
  const extension = (file.name.split('.').pop() ?? 'jpg').toLowerCase();
  const allowed = ['jpg', 'jpeg', 'png', 'webp', 'pdf'];
  if (!allowed.includes(extension)) {
    throw new Error('Only JPG, PNG, WEBP or PDF documents are accepted.');
  }
  const safeName = `${Date.now()}_${file.name
    .replace(/[^a-zA-Z0-9._-]+/g, '-')
    .slice(-60)}`;
  const path = `${userId}/${safeName}`;
  try {
    const { error } = await supabase.storage
      .from(VERIFICATION_BUCKET)
      .upload(path, file, {
        contentType: file.type || 'application/octet-stream',
        upsert: false,
        cacheControl: '3600',
      });
    if (error) throw new Error(describeError(error));
    return path;
  } catch (error) {
    throw new Error(describeError(error));
  }
}
