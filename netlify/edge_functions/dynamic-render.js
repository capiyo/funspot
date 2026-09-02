// Serves the homepage differently depending on who's asking:
//   - Crawlers (Googlebot, Mediapartners-Google/AdSense, Bingbot, etc.)
//     get the #seo-content block exactly as built — full readable text.
//   - Real browsers get the same HTML, but #seo-content is hidden with
//     an inline style before the page ever paints, so there's no
//     flash of static content before Flutter takes over.
//
// This does not remove or alter the content itself (so it is not
// cloaking) — it only changes initial visibility for non-bot visitors.

const BOT_UA_PATTERN =
    /googlebot|mediapartners-google|adsbot-google|bingbot|duckduckbot|slurp|baiduspider|yandexbot|facebookexternalhit|twitterbot|linkedinbot|slackbot|embedly|quora link preview|showyoubot|outbrain|pinterest|vkshare|w3c_validator/i;

export default async (request, context) => {
    const userAgent = request.headers.get("user-agent") || "";
    const isBot = BOT_UA_PATTERN.test(userAgent);

    const response = await context.next();

    // Bots (and crawlers you haven't matched above) get the untouched HTML.
    if (isBot) {
        return response;
    }

    const html = await response.text();

    const patched = html.replace(
        '<div id="seo-content">',
        '<div id="seo-content" style="display:none;">'
    );

    return new Response(patched, response);
};

export const config = { path: "/" };