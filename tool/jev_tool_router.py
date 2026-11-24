"""Jev-Governed Tool Decision & Routing Engine for Antigravity (AGY).

Uses TypeSafe Jev (System One) to evaluate current application state,
task context, and available tool capabilities in ~100 ms to deterministically
choose the next tool call.
"""

from __future__ import annotations

import os
import sys
from dataclasses import dataclass
from typing import Any, Dict, Optional

sys.path.insert(0, r"C:\Users\mtech\.local\share\mimocode\typesafe-harness")
from typesafe_sdk import TypeSafeClient, Choice, Noul

AGY_TOOLS_RUBRIC = {
    "view_file": (
        "Read specific files, source code, configs, or line ranges when the file path is known."
    ),
    "replace_file_content": (
        "Make precise in-place modifications to existing code or config files."
    ),
    "write_to_file": (
        "Create new files, scratch scripts, or persistent markdown artifacts."
    ),
    "grep_search": (
        "Search codebase for regex or string patterns (function names, imports, symbols, errors)."
    ),
    "fff_grep": (
        "Fast frecency-ranked identifier search within a specific subfolder (e.g. 'lib/ <term>', 'test/ <term>', 'tool/ <term>'). Always scope to a subfolder."
    ),
    "fff_find_files": (
        "Explore which files or modules exist for a topic or keyword within a target folder."
    ),
    "fff_multi_grep": (
        "Search 2+ identifiers or naming variants at once (OR logic) with a directory constraint."
    ),
    "find_by_name": (
        "Locate file paths or directories matching a glob pattern or extension."
    ),
    "list_dir": (
        "Inspect the contents of a directory to understand folder hierarchy or file presence."
    ),
    "run_command": (
        "Execute PowerShell commands, build tools, tests, linter, git, or runtime scripts."
    ),
    "manage_task": (
        "Inspect, send input to, or kill background tasks and processes."
    ),
    "invoke_subagent": (
        "Delegate complex, broad, or long-running tasks to an isolated subagent."
    ),
    "search_web": (
        "Search Google/web for external documentation, libraries, or unknown errors."
    ),
    "read_url_content": (
        "Download and read documentation or web page markdown from a known URL."
    ),
    "ask_question": (
        "Prompt the user with multiple-choice questions when the request is ambiguous or requires approval."
    ),
    "finish_turn": (
        "The request has been fully satisfied and no further tool execution is needed; respond to user."
    ),
}


@dataclass
class ToolDecision:
    selected_tool: str
    confidence: float
    probabilities: Dict[str, float]
    is_high_confidence: bool
    needs_clarification: bool
    clarification_probability: float
    rationale: str

    def summary(self) -> str:
        status = "DETERMINISTIC EXECUTION" if self.is_high_confidence else "ESCALATE / CONFIRM"
        return (
            f"Jev Tool Decision: [{self.selected_tool}] "
            f"(Confidence: {self.confidence:.2f} | Clarification Prob: {self.clarification_probability:.2f} | Policy: {status})"
        )


class JevToolRouter:
    def __init__(self, client: Optional[TypeSafeClient] = None):
        self.client = client or TypeSafeClient()

    def route(
        self,
        user_request: str,
        current_step: str,
        workspace_context: str,
        additional_evidence: Optional[Dict[str, Any]] = None,
    ) -> ToolDecision:
        state = {
            "user_request": user_request,
            "current_step": current_step,
            "workspace_context": workspace_context,
            "additional_evidence": additional_evidence or {},
        }

        question_tool = Choice(
            instructions=(
                "Given the user request in `user_request`, current step in `current_step`, "
                "and workspace state in `workspace_context`, which AGY tool MUST be called next? "
                "Select the single most direct and appropriate tool from criteria."
            ),
            criteria=AGY_TOOLS_RUBRIC,
        )

        question_clarification = Noul(
            instructions=(
                "Does the user request in `user_request` contain ambiguity, underspecified parameters, "
                "or competing targets that require confirmation or clarification from the user before executing?"
            )
        )

        evaluation = self.client.system_one(
            state=state,
            questions={
                "tool_selection": question_tool,
                "needs_clarification": question_clarification,
            },
            model="jev-latest",
        )

        answer_tool = evaluation.answers["tool_selection"]
        answer_clarification = evaluation.answers["needs_clarification"]

        chosen = answer_tool.choice
        confidence = answer_tool.confidence
        probabilities = answer_tool.probabilities
        clarification_prob = answer_clarification.noul
        needs_clarify = clarification_prob >= 0.60

        # Strict Confidence-Gating & Clarification Policy:
        # If clarification is warranted or choice confidence < 0.85, force ask_question / confirmation.
        if needs_clarify or confidence < 0.85:
            selected_tool = "ask_question"
            is_high_confidence = False
            rationale = (
                f"Clarification required (clarification_prob={clarification_prob:.2f}, choice_conf={confidence:.2f}). "
                f"Candidate tool was '{chosen}'. Gating policy mandates asking user for clarification first."
            )
        else:
            selected_tool = chosen
            is_high_confidence = True
            rationale = f"Selected {chosen} with {confidence:.1%} confidence based on context."

        return ToolDecision(
            selected_tool=selected_tool,
            confidence=confidence,
            probabilities=probabilities,
            is_high_confidence=is_high_confidence,
            needs_clarification=needs_clarify,
            clarification_probability=clarification_prob,
            rationale=rationale,
        )


def demo():
    router = JevToolRouter()

    test_scenarios = [
        {
            "user_request": "What does lib/app.dart do?",
            "current_step": "Need to inspect the contents of lib/app.dart to see its classes",
            "workspace_context": "Repository has lib/app.dart (7911 bytes)",
        },
        {
            "user_request": "Run flutter analyze to check for linter warnings",
            "current_step": "Need to execute the analyze command in terminal",
            "workspace_context": "Workspace is Flutter project at E:/youtube downloader",
        },
        {
            "user_request": "Find all places where getVideoInfo is called",
            "current_step": "Search the codebase for getVideoInfo callers",
            "workspace_context": "Flutter codebase with services and providers",
        },
        {
            "user_request": "Thank you, that explains everything!",
            "current_step": "User expresses satisfaction with the completed explanation",
            "workspace_context": "All questions answered, fixes verified",
        }
    ]

    print("=== Testing Jev Tool Router ===")
    for scenario in test_scenarios:
        decision = router.route(
            user_request=scenario["user_request"],
            current_step=scenario["current_step"],
            workspace_context=scenario["workspace_context"],
        )
        print(decision.summary())
        print(f"   Context: {scenario['user_request']}")
        print(f"   Probabilities: {decision.probabilities}\n")


if __name__ == "__main__":
    demo()
