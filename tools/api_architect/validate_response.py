import logging

logger = logging.getLogger("ValidateResponse")

def validate_architect_payload(payload: dict) -> bool:
    """
    Since OpenAI Structured Outputs guarantee schema adherence at the API level,
    this function acts as a quick local sanity check before writing to disk.
    If it passes, we return True. Else we raise ValueError.
    """
    required_keys = [
        "spec_id", "title", "status", "priority", 
        "goal_scope", "problem_statement", "architectural_decisions",
        "file_structure", "logic_data_flow", "constraints",
        "acceptance_criteria", "implementation_order", "immediate_next_actions"
    ]
    
    missing = [k for k in required_keys if k not in payload]
    if missing:
        logger.error(f"Validation FAILED! Missing required keys: {missing}")
        raise ValueError(f"Malformed OpenAI Response. Missing keys: {missing}")
        
    logger.info("Validation passed successfully.")
    return True
