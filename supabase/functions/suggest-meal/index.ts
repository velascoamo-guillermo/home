import Anthropic from "npm:@anthropic-ai/sdk";

const anthropic = new Anthropic({ apiKey: Deno.env.get("ANTHROPIC_API_KEY")! });

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });

  try {
    const { stock, slot, plannedTitles } = await req.json();

    const stockList = (stock ?? [])
      .map((s: { name: string; totalUnits: number }) => `- ${s.name} (${s.totalUnits} unidades)`)
      .join("\n");
    const avoid = (plannedTitles ?? []).join(", ");

    const prompt = `Eres un asistente de planificación de comidas. Sugiere UNA comida para ${
      slot === "lunch" ? "el almuerzo" : "la cena"
    } usando preferentemente el stock disponible:
${stockList || "(sin stock)"}

Evita repetir estas comidas ya planificadas esta semana: ${avoid || "(ninguna)"}.

Responde SOLO con JSON válido — sin markdown, sin texto extra — con este esquema exacto:
{
  "title": "string",
  "products": [{"name": "string que coincida con el stock", "quantity": número}],
  "servings": número o null,
  "calories": número o null,
  "protein_g": número o null,
  "carbs_g": número o null,
  "fat_g": número o null
}
Usa exactamente los nombres del stock en "products". Estima nutrición para el plato completo.`;

    const msg = await anthropic.messages.create({
      model: "claude-opus-4-8",
      max_tokens: 1024,
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
