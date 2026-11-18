import { useRef, useState } from 'react';
import { Alert } from './ui';
import { Icon } from './Icon';
import { describeError } from '../lib/supabase';
import { uploadTourismImage, type UploadFolder } from '../lib/storage';

interface GalleryUploadProps {
  folder: UploadFolder;
  value: string | null;
  onChange: (url: string | null) => void;
  label?: string;
}

/**
 * Gallery picker with live preview. Uploads the chosen photo to the public
 * `tourism-media` bucket and hands the public URL back to the form, which saves
 * it into `image_url`.
 */
export function GalleryUpload({
  folder,
  value,
  onChange,
  label = 'Gallery photo',
}: GalleryUploadProps) {
  const inputRef = useRef<HTMLInputElement | null>(null);
  const [uploading, setUploading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [localPreview, setLocalPreview] = useState<string | null>(null);

  const preview = localPreview ?? value;

  const pick = async (file: File | undefined) => {
    if (!file) return;
    setError(null);
    const objectUrl = URL.createObjectURL(file);
    setLocalPreview(objectUrl);
    setUploading(true);
    try {
      const publicUrl = await uploadTourismImage(file, folder);
      onChange(publicUrl);
      setLocalPreview(null);
    } catch (uploadError) {
      setError(describeError(uploadError));
      setLocalPreview(null);
    } finally {
      setUploading(false);
      if (inputRef.current) inputRef.current.value = '';
    }
  };

  return (
    <div>
      <span className="field-label">
        {label}
        <span className="ml-2 text-[11px] font-normal text-slate-400">
          Uploads to tourism-media/{folder}
        </span>
      </span>

      <div className="mt-1 flex flex-wrap items-start gap-3">
        <div className="h-24 w-36 overflow-hidden rounded-lg border border-slate-200 bg-surface">
          {preview ? (
            <img
              src={preview}
              alt="Selected tourism gallery preview"
              className="h-full w-full object-cover"
            />
          ) : (
            <div className="flex h-full w-full flex-col items-center justify-center gap-1 text-slate-400">
              <Icon name="image" className="h-6 w-6" />
              <span className="text-[10px] uppercase tracking-wide">No photo</span>
            </div>
          )}
        </div>

        <div className="flex flex-col gap-2">
          <input
            ref={inputRef}
            type="file"
            accept="image/*"
            className="hidden"
            onChange={(event) => void pick(event.target.files?.[0])}
          />
          <button
            type="button"
            disabled={uploading}
            onClick={() => inputRef.current?.click()}
            className="inline-flex items-center gap-2 rounded-lg border border-forest/25 bg-white px-3 py-2 text-xs font-semibold text-forest transition hover:border-forest disabled:cursor-not-allowed disabled:opacity-60"
          >
            <Icon name="image" className="h-3.5 w-3.5" />
            {uploading
              ? 'Uploading…'
              : preview
                ? 'Replace photo'
                : 'Choose from gallery'}
          </button>
          {preview ? (
            <button
              type="button"
              onClick={() => {
                onChange(null);
                setLocalPreview(null);
              }}
              className="text-left text-[11px] font-medium text-red-600 hover:underline"
            >
              Remove photo
            </button>
          ) : null}
        </div>
      </div>

      {value ? (
        <p className="mt-1 break-all text-[10px] text-slate-400">{value}</p>
      ) : null}
      {error ? (
        <div className="mt-2">
          <Alert tone="error">{error}</Alert>
        </div>
      ) : null}
    </div>
  );
}
