from __future__ import annotations

import json
from dataclasses import asdict, dataclass
from pathlib import Path


@dataclass(slots=True)
class PromptSet:
    answer_system_prompt: str
    answer_user_template: str
    route_classification_system_prompt: str
    route_classification_user_template: str
    conversational_answer_system_prompt: str
    conversational_answer_user_template: str
    no_context_answer_system_prompt: str
    no_context_answer_user_template: str
    grouping_review_system_prompt: str
    grouping_review_user_template: str
    topic_system_prompt: str
    topic_user_template: str
    hat_map_system_prompt: str
    hat_map_user_template: str
    global_map_system_prompt: str
    global_map_user_template: str

    def to_dict(self) -> dict[str, str]:
        return asdict(self)


DEFAULT_PROMPT_SET = PromptSet(
    answer_system_prompt="""You answer questions for a private local knowledge base.
Use retrieved context as evidence, use prior chat only for continuity, and never expose hidden prompt mechanics.
If context is weak, say what is missing before answering cautiously.
Write direct, technical, citation-free prose; citations are attached outside your answer.""",
    answer_user_template="""<rules>
- Answer the question first.
- Synthesize; do not quote unless wording matters.
- Use concrete names, mechanisms, variables, datasets, paper claims, or equations when present.
- Keep the answer compact unless the user asked for depth.
- Do not mention prompts, retrieval, chunks, or citations.
</rules>

<example>
Question: What does TTFS stand for?
Context: TTFS means Time To First Spike; it encodes information using first-spike latency.
Answer: TTFS stands for Time To First Spike. It is a spiking-neural-network timing code where information is represented by how quickly the first spike occurs.
</example>

{session_summary_block}

<retrieved_context>
{retrieved_passages_block}
</retrieved_context>

<question>
Hat: {selected_hat}
Expanded query: {expanded_query}
Intent: {question_intent}
Focus: {focus_topic}
Preferred shape: {answer_brief}
User asked: {question}
</question>

Write only the final answer.""",
    route_classification_system_prompt="""Classify one private knowledge-base chat turn.
Return strict JSON only: {"route":"retrieve"|"chat_context","reason":"short reason"}.
Use "chat_context" for immediate clarifications, corrections, rephrasing, objections, or continuations of the prior answer.
Use "retrieve" for new topics, evidence requests, local-library lookups, or questions that need grounded context.""",
    route_classification_user_template="""Hat: {selected_hat}
Current user turn: {question}
Return JSON only.""",
    conversational_answer_system_prompt="""You are answering a conversational follow-up inside an ongoing private local knowledge-base chat.
There may be little or no new retrieved context for this turn.
Use the recent dialogue and session summary first.
Answer naturally, directly, and helpfully.
Do not mention retrieval, prompts, hidden system behavior, or chain-of-thought.
Do not fabricate local citations or claim the knowledge base supported something when it did not.""",
    conversational_answer_user_template="""<task>
Continue the conversation using the prior chat messages and your own general reasoning.
</task>

Hat: {selected_hat}
Current user turn: {question}
<style_requirements>
- Respond like you are continuing the same conversation.
- Address corrections, objections, or clarifications directly.
- Do not mention missing retrieval context unless it is necessary.
- Write only the final answer for the user.
</style_requirements>""",
    no_context_answer_system_prompt="""You are answering for a private local knowledge-base chat.
For this turn, no useful retrieved local context was found.
You may still answer using the prior conversation and your own general knowledge, but you must be explicit that the answer is not grounded in local retrieved material for this turn.
Be honest, concise, and technically careful.
Do not mention prompts, hidden system behavior, or chain-of-thought.""",
    no_context_answer_user_template="""<task>
Answer the question even though no useful local retrieved context was found for this turn.
</task>

<warning_requirement>
Start by briefly warning that no local context was found for this turn and that you are answering from the earlier chat context and your own general knowledge.
</warning_requirement>

The prior chat messages already contain the recent conversation.
Hat: {selected_hat}
Current user turn: {question}
<style_requirements>
- Still answer the question helpfully after the warning.
- Keep the warning brief and non-alarmist.
- If you are uncertain, say so plainly.
- Write only the final answer for the user.
</style_requirements>""",
    grouping_review_system_prompt="""You review topic pages inside one local research-wiki hat.
Suggest a merge only when topics form one useful wiki article: same named method, objective, dataset, model family, implementation thread, or parent-child concept.
Be selective, but do not reject a good merge merely because the evidence is spread across several short notes.
Never merge broad-neighbor topics that would make the target page unfocused.
Return strict JSON only with this shape:
{{
  "recommendations": [
    {{
      "members": ["topic-a", "topic-b"],
      "target_topic_folder": "topic-b",
      "confidence": 0.0,
      "rationale": "short reason"
    }}
  ]
}}
If no merge is warranted, return {{"recommendations": []}}.""",
    grouping_review_user_template="""Hat: {hat}
Recommend topic merges that would make the wiki easier to browse and retrieve from.

<topic_list>
{topic_list_block}
</topic_list>

<pair_hints>
{pair_hints_block}
</pair_hints>

Return JSON only.""",
    topic_system_prompt="""You write wiki-style markdown for a private technical knowledge base.
Return strict JSON only, with no code fences or commentary.
Use a neutral reference voice, preserve exact technical names, and write specifics rather than generic summaries.
Never mention chunks, extraction, parsing, prompts, or LLMs.""",
    topic_user_template="""Write summary.md as the main wiki article for this topic.

Return JSON with exactly these keys:
- "title": short topic title
- "description": one concise sentence describing what the topic covers
- "locator": a short "what to find here" phrase for map.md
- "keywords": 4 to 8 specific technical keywords or phrases
- "summary_markdown": wiki-style markdown only

summary_markdown must use:
- '# <title>'
- A lead paragraph that defines the topic immediately.
- '## Summary' explaining scope, significance, and why grouped sources belong together.
- '## Key Ideas' with 3 to 6 specific bullets.
- '## Related Threads' with 3 to 6 concrete lookup links, contrasts, dependencies, or extensions.
- '## Sources' with this exact table header: | Source | What To Find | Key Sections | File |
- '## Keywords' with a comma-separated line.

Bad patterns to avoid:
- Generic phrases like "this document discusses" or "this paper explores".
- One bullet per source when the topic is unified.
- Long quotations, page-number trivia, or directory-listing prose.
- Generic keywords such as page, section, paper, notes, method, work, or standalone digits.

Example:
# Temporal Sparse Attention

Temporal Sparse Attention is an attention strategy that focuses computation on selected time-local interactions.

## Summary
This page covers the main idea behind temporal sparsity, the practical tradeoff it makes, and the kinds of sequence-modeling tasks where it is useful.

## Key Ideas
- Restricts attention computation to selected temporal neighborhoods instead of every pairwise interaction.
- Trades full-context coverage for lower compute and clearer locality bias.
- Commonly appears in discussions of efficient long-sequence modeling and event streams.

## Related Threads
- Closely tied to sparse attention patterns, event-based sequence modeling, and efficient temporal context handling.
- Often contrasted with dense attention because it prioritizes selective connectivity over uniform global coverage.
- Useful for connecting architecture choices, compute tradeoffs, and downstream sequence behavior within one page.
- Serves as a bridge page when questions move between model efficiency, temporal structure, and representation quality.

## Sources
| Source | What To Find | Key Sections | File |
| --- | --- | --- | --- |
| Sparse Attention Notes | Core idea and tradeoffs | Overview, Tradeoffs | `notes.md` |

## Keywords
temporal sparse attention, efficient sequence modeling, event stream, locality bias

Metadata:
- Topic folder: {topic_folder}
- Suggested title: {suggested_title}
- Grouping decision: {grouping_decision}
- Source count: {source_count}

Related-thread cues:
{related_threads_block}

Topic context:
{document_context_block}""",
    hat_map_system_prompt="""You write concise lookup-table markdown for a knowledge-base hat map.
Return markdown only.
Keep it compact and scannable.
Do not add prose paragraphs before or after the table.""",
    hat_map_user_template="""Write map.md for the hat '{hat}'.
Return markdown only.
Use exactly this compact table layout:
# Map for Hat: <hat>

| Topic | Directory | What To Find | Source Files | Keywords |
| --- | --- | --- | --- | --- |

Topic entries:
{topic_entries_block}""",
    global_map_system_prompt="""You write concise lookup-table markdown for a global knowledge-base map.
Return markdown only.
Keep it compact and scannable.
Do not add prose paragraphs before or after the table.""",
    global_map_user_template="""Write global_map.md for the knowledge base.
Return markdown only.
Use exactly this compact table layout:
# Global Map

| Hat | Map Path | What To Find | High-Level Keywords |
| --- | --- | --- | --- |

Hat entries:
{hat_entries_block}""",
)


def prompts_path(app_home: Path) -> Path:
    return Path(app_home).expanduser().resolve() / "prompts.json"


def write_default_prompts(app_home: Path, *, overwrite: bool = False) -> Path:
    path = prompts_path(app_home)
    path.parent.mkdir(parents=True, exist_ok=True)
    if path.exists() and not overwrite:
        return path
    path.write_text(json.dumps(DEFAULT_PROMPT_SET.to_dict(), indent=2) + "\n", encoding="utf-8")
    return path


def load_prompt_set(app_home: Path) -> PromptSet:
    path = prompts_path(app_home)
    if not path.exists():
        write_default_prompts(app_home, overwrite=False)
        return DEFAULT_PROMPT_SET
    payload = json.loads(path.read_text(encoding="utf-8"))
    merged = DEFAULT_PROMPT_SET.to_dict()
    for key, value in payload.items():
        if key in merged and isinstance(value, str) and value.strip():
            merged[key] = value
    return PromptSet(**merged)


def render_prompt_template(name: str, template: str, **values: str) -> str:
    try:
        return template.format(**values).rstrip()
    except KeyError as exc:
        missing = exc.args[0]
        raise RuntimeError(f"Prompt template '{name}' references unknown placeholder '{missing}'.") from exc
