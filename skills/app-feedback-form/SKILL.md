---
name: app-feedback-form
description: >
  Add the standard in-app "Report a bug / Send feedback" email section to an
  app's Settings screen, matching the format shared by Anemoi, Ika Manager,
  and Hoppity. Use when the user asks to add a feedback form, bug-report
  button, support email section, or "contact us" entry to an app — the goal
  is that every app presents feedback the same way: two actions that open the
  user's email client with a prefilled subject and diagnostic body.
---

# app-feedback-form

Adds the house-standard feedback/bug-report section to an app. The standard
exists so every app collects feedback identically: a user taps one of two
actions, their own email client opens with the subject, app identity, and
device diagnostics already filled in, and the mail routes to a per-app inbox.

## The standard

1. **Placement** — the section is the last *interactive* content section on the
   Settings screen, placed **directly above the About section** (or at the very
   end if the app has no About section).

2. **Native look** — render the section with the app's *existing* settings
   primitives (section header + card + rows, callout cards, whatever the app
   already uses). Do not invent a new visual component; the standard is the
   behavior, not one specific widget.

3. **Two actions**, in this order:
   - **Report a bug**
   - **Send feedback**

4. **Email launch** — `Intent.ACTION_SENDTO` with a `mailto:` URI (never
   `ACTION_SEND`; SENDTO restricts the chooser to actual email apps). Subject
   and body are URL-encoded query parameters (`Uri.encode`).

5. **Subject format** — `[AppName] Bug Report` / `[AppName] Feedback`. The
   bracketed app name is what lets one shared inbox filter per app.

6. **Body template** — a diagnostics header, a blank line, then guided prompts:

   ```
   App: <AppName>
   Request: Bug Report | Feedback
   App version: <versionName> (<versionCode>)
   Device: <Build.MANUFACTURER> <Build.MODEL>
   Android: <Build.VERSION.RELEASE>

   — bug report prompts —
   What happened?

   Steps to reproduce:
   1.
   2.
   3.

   What did you expect to happen?

   — feedback prompt —
   What would you like to share or suggest?
   ```

7. **No-email-app fallback** — catch `ActivityNotFoundException` and show an
   inline message naming the address so the user can write manually
   ("No email app was found. Write to <address> directly."). Never crash.

8. **Strings** — all user-visible text goes wherever the app keeps its strings
   (e.g. `strings.xml`); addresses and subjects are fine as non-translatable
   string resources.

9. **Addresses** — each app has its own inbox(es). Known apps:

   | App | Bug reports | Feedback |
   |---|---|---|
   | Hoppity | bugs@floppity.app | support@floppity.app |
   | Anemoi | Anubis4ge@gmail.com | Anubis4ge@gmail.com |
   | Ika Manager | (its existing support address) | (same) |

   A single shared address for both actions is acceptable — the subject tag
   distinguishes them. When adding the section to a new app, ask which
   address(es) to use if not obvious, and add the app to this table.

## Reference implementation (Kotlin / Compose)

Adapt names and UI primitives to the target app:

```kotlin
private fun launchSupportEmail(context: Context, isBugReport: Boolean): String? {
    val address = if (isBugReport) BUGS_EMAIL else SUPPORT_EMAIL
    val subject = if (isBugReport) "[AppName] Bug Report" else "[AppName] Feedback"
    val body = buildString {
        appendLine("App: AppName")
        appendLine("Request: " + if (isBugReport) "Bug Report" else "Feedback")
        appendLine("App version: ${BuildConfig.VERSION_NAME} (${BuildConfig.VERSION_CODE})")
        appendLine("Device: ${Build.MANUFACTURER} ${Build.MODEL}")
        appendLine("Android: ${Build.VERSION.RELEASE}")
        appendLine()
        if (isBugReport) {
            appendLine("What happened?")
            appendLine()
            appendLine("Steps to reproduce:")
            appendLine("1. ")
            appendLine("2. ")
            appendLine("3. ")
            appendLine()
            appendLine("What did you expect to happen?")
        } else {
            appendLine("What would you like to share or suggest?")
        }
    }
    val uri = Uri.parse(
        "mailto:$address?subject=${Uri.encode(subject)}&body=${Uri.encode(body)}",
    )
    return try {
        context.startActivity(Intent(Intent.ACTION_SENDTO, uri))
        null // success — no message to show
    } catch (_: ActivityNotFoundException) {
        "No email app was found. Write to $address directly."
    }
}
```

The two settings rows call this and display the returned string (if any) as an
inline error below the section.

## Checklist before finishing

- [ ] Section sits directly above About (or last if no About)
- [ ] Uses the app's existing settings UI primitives
- [ ] Both subjects carry the `[AppName]` tag
- [ ] Body includes version, versionCode, device, and Android release
- [ ] `ActivityNotFoundException` handled with an inline fallback message
- [ ] Strings externalized per the app's convention
- [ ] New app's addresses recorded in the table above (edit this skill)
