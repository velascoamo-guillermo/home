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
    const { stock, slots, planned } = await req.json();

    const stockList = (stock ?? [])
      .map((s: { name: string; totalUnits: number }) => `- ${s.name} (${s.totalUnits} unidades)`)
      .join("\n");

    const slotsList = (slots ?? [])
      .map((s: { day: number; slot: string }) => `- ${dayName(s.day)} / ${slotName(s.slot)} (day=${s.day}, slot="${s.slot}")`)
      .join("\n");

    const plannedList = (planned ?? [])
      .map((p: { day: number; slot: string; title: string }) => `- ${dayName(p.day)} / ${slotName(p.slot)}: ${p.title}`)
      .join("\n");

    const prompt = `Eres un asistente de planificación de comidas semanal. Planifica comidas para TODOS estos huecos vacíos de la semana, de una sola vez:
${slotsList || "(ninguno)"}

Stock disponible (presupuesto compartido para TODA la semana — no excedas las unidades totales sumando todas las comidas):
${stockList || "(sin stock)"}

Comidas ya planificadas esta semana (NO las repitas, y tenlas en cuenta para variar):
${plannedList || "(ninguna)"}

Reglas:
- No repitas el mismo plato en distintos huecos.
- Prioriza comidas equilibradas y saludables: incluye proteína, verdura y carbohidrato cuando sea posible; varía a lo largo de la semana y evita repetir el mismo tipo de plato muchos días.
- Usa preferentemente el stock disponible, repartiendo las unidades entre toda la semana sin pasarte del total de cada producto.
- Usa exactamente los nombres del stock en "products".
- Devuelve un objeto por cada hueco solicitado, con su day y slot exactos.

Responde SOLO con JSON válido — sin markdown, sin texto extra — un array con este esquema exacto:
[
  {
    "day": número (1=lunes … 7=domingo),
    "slot": "lunch" o "dinner",
    "title": "string",
    "products": [{"name": "string que coincida con el stock", "quantity": número}],
    "servings": número o null,
    "calories": número o null,
    "protein_g": número o null,
    "carbs_g": número o null,
    "fat_g": número o null
  }
]
Estima la nutrición para el plato completo.`;

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
