import bcrypt from 'bcryptjs';
import { JwtPayload, UserSession } from './types';

export class AuthUtil {
  /**
   * Hashes a password using bcrypt.
   */
  static hashPassword(password: string): string {
    return bcrypt.hashSync(password, 10);
  }

  /**
   * Compares a password against a stored bcrypt hash.
   */
  static comparePassword(password: string, hash: string): boolean {
    try {
      return bcrypt.compareSync(password, hash);
    } catch {
      return false;
    }
  }

  /**
   * Signs a JWT using WebCrypto HMAC-SHA256.
   * Valid for 30 days.
   */
  static async signJwt(user: UserSession, secret: string, expiresInSeconds = 30 * 24 * 3600): Promise<string> {
    const now = Math.floor(Date.now() / 1000);
    const payload: JwtPayload = {
      sub: user.id,
      username: user.username,
      iat: now,
      exp: now + expiresInSeconds,
    };

    const header = { alg: 'HS256', typ: 'JWT' };
    const encodedHeader = AuthUtil.base64UrlEncode(JSON.stringify(header));
    const encodedPayload = AuthUtil.base64UrlEncode(JSON.stringify(payload));
    const dataToSign = `${encodedHeader}.${encodedPayload}`;

    const key = await AuthUtil.getHmacKey(secret);
    const signatureBuffer = await crypto.subtle.sign(
      'HMAC',
      key,
      new TextEncoder().encode(dataToSign)
    );

    const encodedSignature = AuthUtil.base64UrlEncodeBytes(new Uint8Array(signatureBuffer));
    return `${dataToSign}.${encodedSignature}`;
  }

  /**
   * Verifies a JWT using WebCrypto HMAC-SHA256.
   * Returns payload if valid, null if invalid or expired.
   */
  static async verifyJwt(token: string, secret: string): Promise<JwtPayload | null> {
    try {
      const parts = token.split('.');
      if (parts.length !== 3) return null;

      const [encodedHeader, encodedPayload, encodedSignature] = parts;
      const dataToSign = `${encodedHeader}.${encodedPayload}`;

      const key = await AuthUtil.getHmacKey(secret);
      const signatureBytes = AuthUtil.base64UrlDecodeBytes(encodedSignature);

      const isValid = await crypto.subtle.verify(
        'HMAC',
        key,
        signatureBytes as ArrayBufferView<ArrayBuffer>,
        new TextEncoder().encode(dataToSign)
      );

      if (!isValid) return null;

      const payloadJson = new TextDecoder().decode(AuthUtil.base64UrlDecodeBytes(encodedPayload));
      const payload: JwtPayload = JSON.parse(payloadJson);

      const now = Math.floor(Date.now() / 1000);
      if (payload.exp && payload.exp < now) {
        return null; // Expired
      }

      return payload;
    } catch {
      return null;
    }
  }

  /**
   * Extracts user ID from Authorization: Bearer <token> header.
   */
  static async authenticateRequest(
    authHeader: string | null | undefined,
    secret: string
  ): Promise<JwtPayload | null> {
    if (!authHeader || !authHeader.startsWith('Bearer ')) return null;
    const token = authHeader.slice(7).trim();
    return await AuthUtil.verifyJwt(token, secret);
  }

  private static async getHmacKey(secret: string): Promise<CryptoKey> {
    const encoder = new TextEncoder();
    return await crypto.subtle.importKey(
      'raw',
      encoder.encode(secret || 'default-fallback-dev-secret-change-in-prod'),
      { name: 'HMAC', hash: 'SHA-256' },
      false,
      ['sign', 'verify']
    );
  }

  private static base64UrlEncode(str: string): string {
    const bytes = new TextEncoder().encode(str);
    return AuthUtil.base64UrlEncodeBytes(bytes);
  }

  private static base64UrlEncodeBytes(bytes: Uint8Array): string {
    let binary = '';
    for (let i = 0; i < bytes.byteLength; i++) {
      binary += String.fromCharCode(bytes[i]);
    }
    return btoa(binary)
      .replace(/\+/g, '-')
      .replace(/\//g, '_')
      .replace(/=+$/, '');
  }

  private static base64UrlDecodeBytes(str: string): Uint8Array {
    let base64 = str.replace(/-/g, '+').replace(/_/g, '/');
    while (base64.length % 4) {
      base64 += '=';
    }
    const binary = atob(base64);
    const bytes = new Uint8Array(binary.length);
    for (let i = 0; i < binary.length; i++) {
      bytes[i] = binary.charCodeAt(i);
    }
    return bytes;
  }
}
