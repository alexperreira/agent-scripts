# Provider-Specific Webhook Handlers

Loaded by `webhook-security` when the receiver being built or reviewed is for one of these
providers. For any other provider, the generic HMAC pattern in the skill body is the starting
point.

---

## Stripe

```ts
import Stripe from 'stripe';

const stripe = new Stripe(process.env.STRIPE_SECRET_KEY!);

export async function handleStripeWebhook(req: Request, res: Response) {
  const sig = req.headers['stripe-signature'];
  const webhookSecret = process.env.STRIPE_WEBHOOK_SECRET!;

  let event: Stripe.Event;
  try {
    // Stripe verifies signature AND timestamp window (prevents replay)
    event = stripe.webhooks.constructEvent(req.body, sig!, webhookSecret);
  } catch (err) {
    logger.warn('Stripe webhook verification failed', { error: err });
    return res.status(400).json({ error: 'Invalid signature' });
  }

  // Always return 200 quickly — process async
  res.status(200).json({ received: true });
  await processStripeEvent(event); // handle after response
}
```

`constructEvent` covers both signature verification and the replay window, so a Stripe receiver
needs no separate timestamp check. `req.body` must still be the raw Buffer.

---

## GitHub

```ts
import { createHmac, timingSafeEqual } from 'crypto';

function verifyGitHubSignature(payload: Buffer, signature: string, secret: string): boolean {
  const expected = 'sha256=' + createHmac('sha256', secret)
    .update(payload)
    .digest('hex');

  const a = Buffer.from(expected);
  const b = Buffer.from(signature);

  // timingSafeEqual throws RangeError on length mismatch — an attacker sending a short
  // header would otherwise produce an uncaught 500. Length-check first, then compare.
  if (a.length !== b.length) return false;
  return timingSafeEqual(a, b);
}

export async function handleGitHubWebhook(req: Request, res: Response) {
  const sig = req.headers['x-hub-signature-256'] as string;
  if (!sig || !verifyGitHubSignature(req.body, sig, process.env.GITHUB_WEBHOOK_SECRET!)) {
    return res.status(401).json({ error: 'Invalid signature' });
  }
  // process...
}
```

GitHub does not sign a timestamp, so a GitHub receiver enforces replay protection itself —
event-ID dedup plus a freshness check on the payload.
