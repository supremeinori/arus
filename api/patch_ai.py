import pathlib

ai_service_path = pathlib.Path("C:/MyProjects/arus/api/src/modules/ai/ai.service.ts")
content = ai_service_path.read_text(encoding="utf-8")

# 1. Update callGemini to accept screenContext?: string
old_call_gemini = """  private async callGemini(
    userMessage: string,
    facts: any[],
    history: ChatMemoryTurn[],
    userContext: { name: string; role: string; outletName?: string }
  ): Promise<string | null> {"""

new_call_gemini = """  private async callGemini(
    userMessage: string,
    facts: any[],
    history: ChatMemoryTurn[],
    userContext: { name: string; role: string; outletName?: string },
    screenContext?: string
  ): Promise<string | null> {"""

content = content.replace(old_call_gemini, new_call_gemini)

# 2. Update systemInstruction in callGemini to include screenContext
old_sys = """      const systemInstruction = `Anda adalah ARUS Business Copilot, asisten kecerdasan bisnis & rekan diskusi keputusan (DSS) pribadi untuk ${userContext.name} (${userContext.role}) di platform bisnis ARUS.""""""
new_sys = """      const screenCtxPart = screenContext ? `\\n[Konteks layar user saat ini: ${screenContext}]` : '';
      const systemInstruction = `Anda adalah ARUS Business Copilot, asisten kecerdasan bisnis & rekan diskusi keputusan (DSS) pribadi untuk ${userContext.name} (${userContext.role}) di platform bisnis ARUS.${screenCtxPart}`;"""

content = content.replace(old_sys, new_sys)

# 3. Update handleChat query type to include screen_context?: string
old_handle_query = """    query: {
      conversation_id?: string;
      message: string;
      outlet_id?: string;
    },"""

new_handle_query = """    query: {
      conversation_id?: string;
      message: string;
      outlet_id?: string;
      screen_context?: string;
    },"""

content = content.replace(old_handle_query, new_handle_query)

# 4. Pass query.screen_context to callGemini
old_call_inv = """    const liveGeminiText = await this.callGemini(userMessage, facts, memory, {
      name: userName,
      role: userRoleTitle,
    });"""

new_call_inv = """    const liveGeminiText = await this.callGemini(userMessage, facts, memory, {
      name: userName,
      role: userRoleTitle,
    }, query.screen_context);"""

content = content.replace(old_call_inv, new_call_inv)

ai_service_path.write_text(content, encoding="utf-8")
print("Successfully patched ai.service.ts via helper script!")
