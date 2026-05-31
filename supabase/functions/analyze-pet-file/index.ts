// supabase/functions/analyze-pet-file/index.ts
import Anthropic from "npm:@anthropic-ai/sdk@0.39.0";

type AnalyzeRequest = {
  storagePath: string; // relative path in pet-files bucket, e.g. "<petId>/<fileId>.pdf"
  mediaType: string;   // "application/pdf" | "image/jpeg" | "image/png"
  petName: string;
};

type AnalyzeResponse =
  | {
      success: true;
      visitDate: string | null;
      diagnosis: string;
      testResults: Record<string, string>;
      medications: string[];
      recommendations: string;
    }
  | { success: false; error: string };

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

// Issue 4: instantiate once at module scope rather than per-request
const anthropic = new Anthropic({
  apiKey: Deno.env.get("CLAUDE_API_KEY") ?? "",
});

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const apiKey =
      req.headers.get("apikey") ?? req.headers.get("x-api-key") ?? "";
    const anonKey = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
    const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
    if (apiKey !== anonKey && apiKey !== serviceKey) {
      // Issue 5: include success: false so Swift ResponseBody decoding succeeds
      return new Response(JSON.stringify({ success: false, error: "Unauthorized" }), {
        status: 401,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // Issue 1: guard against missing CLAUDE_API_KEY before doing any work
    if (!Deno.env.get("CLAUDE_API_KEY")) {
      return new Response(JSON.stringify({ success: false, error: "CLAUDE_API_KEY not configured" }), {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const { storagePath, mediaType, petName }: AnalyzeRequest = await req.json();

    // Validate required fields before using them
    if (!storagePath || !mediaType || !petName) {
      return new Response(JSON.stringify({ success: false, error: "Missing required fields: storagePath, mediaType, petName" }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // Construct file URL server-side — never accept a URL from the client (SSRF)
    const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
    const fileUrl = `${supabaseUrl}/storage/v1/object/public/pet-files/${storagePath}`;

    // Fetch file and convert to base64
    const fileResponse = await fetch(fileUrl);
    if (!fileResponse.ok) {
      throw new Error(`Failed to fetch file: ${fileResponse.statusText}`);
    }
    const buffer = await fileResponse.arrayBuffer();
    const bytes = new Uint8Array(buffer);
    let binary = "";
    const chunkSize = 8192;
    for (let i = 0; i < bytes.length; i += chunkSize) {
      binary += String.fromCharCode(...bytes.subarray(i, i + chunkSize));
    }
    const fileBase64 = btoa(binary);

    // Build content block: document for PDF, image for everything else
    const isPdf = mediaType === "application/pdf";
    const contentBlock = isPdf
      ? {
          type: "document" as const,
          source: {
            type: "base64" as const,
            media_type: "application/pdf" as const,
            data: fileBase64,
          },
        }
      : {
          type: "image" as const,
          source: {
            type: "base64" as const,
            media_type: (mediaType === "image/png"
              ? "image/png"
              : "image/jpeg") as "image/png" | "image/jpeg",
            data: fileBase64,
          },
        };

    const prompt = `You are a veterinary records assistant. Analyze the attached document for ${petName} and extract the following information. Respond with ONLY valid JSON matching this exact schema — no markdown, no extra text:

{
  "visitDate": "YYYY-MM-DD or null",
  "diagnosis": "string",
  "testResults": {"test name": "value"},
  "medications": ["string"],
  "recommendations": "string"
}

If a field is not present in the document, use null for dates and empty string/array for others.`;

    const message = await anthropic.messages.create({
      model: "claude-sonnet-4-6",
      max_tokens: 1024,
      messages: [
        {
          role: "user",
          content: [
            contentBlock,
            { type: "text", text: prompt },
          ],
        },
      ],
    });

    const responseText =
      message.content[0].type === "text" ? message.content[0].text : "";

    // Accept both raw JSON and markdown code fences
    const jsonMatch =
      responseText.match(/```json\n([\s\S]*?)\n```/) ??
      responseText.match(/\{[\s\S]*\}/);

    if (!jsonMatch) {
      throw new Error("Failed to parse Claude response as JSON");
    }

    const data = JSON.parse(jsonMatch[1] ?? jsonMatch[0]);

    const response: AnalyzeResponse = {
      success: true,
      visitDate: data.visitDate ?? null,
      diagnosis: data.diagnosis ?? "",
      testResults: data.testResults ?? {},
      medications: data.medications ?? [],
      recommendations: data.recommendations ?? "",
    };

    return new Response(JSON.stringify(response), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  } catch (error) {
    console.error("Analysis error:", error);
    const errorResponse: AnalyzeResponse = {
      success: false,
      error: error instanceof Error ? error.message : "Unknown error",
    };
    return new Response(JSON.stringify(errorResponse), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});
