import Anthropic from "npm:@anthropic-ai/sdk";

const anthropic = new Anthropic({ apiKey: Deno.env.get("CLAUDE_API_KEY") ?? "" });

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

const dayName = (d: number) =>
  ["", "lunes", "martes", "miércoles", "jueves", "viernes", "sábado", "domingo"][d] ?? `día ${d}`;

const slotName = (s: string) => (s === "lunch" ? "almuerzo" : "cena");

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });

  try {
    const { catalog, stock, slots, planned } = await req.json();

    const catalogList = (catalog ?? [])
      .map((c: { id: string; title: string }) => `- ${c.title} (meal_id="${c.id}")`)
      .join("\n");

    const levelLabel: Record<string, string> = {
      out: "agotado", low: "queda poco", medium: "a medias", full: "lleno",
    };
    const stockList = (stock ?? [])
      .map((s: { name: string; level?: string; totalUnits?: number }) =>
        s.level
          ? `- ${s.name} (${levelLabel[s.level] ?? s.level})`
          : `- ${s.name} (${s.totalUnits ?? 0} unidades)`)
      .join("\n");

    const slotsList = (slots ?? [])
      .map((s: { day: number; slot: string }) => `- ${dayName(s.day)} / ${slotName(s.slot)} (day=${s.day}, slot="${s.slot}")`)
      .join("\n");

    const plannedList = (planned ?? [])
      .map((p: { day: number; slot: string; title: string }) => `- ${dayName(p.day)} / ${slotName(p.slot)}: ${p.title}`)
      .join("\n");

    const prompt = `Eres un asistente de planificación de comidas semanal. Asigna una comida del catálogo a CADA uno de estos huecos vacíos de la semana:
${slotsList || "(ninguno)"}

Catálogo de comidas disponibles (elige SOLO de aquí, usando su meal_id exacto):
${catalogList || "(vacío)"}

Stock disponible (orientativo, para preferir platos cocinables):
${stockList || "(sin stock)"}

Comidas ya planificadas esta semana (tenlas en cuenta para variar):
${plannedList || "(ninguna)"}

Reglas:
- Elige únicamente comidas del catálogo; nunca inventes platos nuevos.
- Evita repetir la misma comida en varios huecos; si hay menos comidas que huecos, reparte las repeticiones lo máximo posible.
- Varía a lo largo de la semana y respecto a lo ya planificado.
- Devuelve un objeto por cada hueco solicitado, con su day y slot exactos.
- Copia exactamente el título de cada comida tal como aparece en el catálogo (sin paráfrasis, sin reescrituras, sin cambios de capitalización).

Responde SOLO con JSON válido — sin markdown, sin texto extra — un array con este esquema exacto:
[
  {
    "day": número (1=lunes … 7=domingo),
    "slot": "lunch" o "dinner",
    "meal_id": "uuid exacto del catálogo",
    "title": "título exacto del catálogo (cópialo tal cual, sin paráfrasis)"
  }
]`;

    const msg = await anthropic.messages.create({
      model: "claude-opus-4-8",
      max_tokens: 4096,
      messages: [{ role: "user", content: prompt }],
    });

    const text = msg.content
      .filter((b: { type: string }) => b.type === "text")
      .map((b: { text: string }) => (b as { type: string; text: string }).text)
      .join("");

    return new Response(text, {
      headers: { ...cors, "Content-Type": "application/json" },
    });
  } catch (e) {
    return new Response(JSON.stringify({ error: String(e) }), {
      status: 500,
      headers: { ...cors, "Content-Type": "application/json" },
    });
  }
});
