import logging
from typing import AsyncGenerator
from fastapi import APIRouter, HTTPException, Request, Depends
from repositories.postgres_repository import PostgresDB
from services.entry_service import EntryService
from models.entry import Entry, EntryCreate, EntryUpdate
from services.summary_service import (
    SummaryNotConfiguredError,
    SummaryService,
    create_summary_service_from_env,
    pick_recent,
)

logger = logging.getLogger("journal")


router = APIRouter()

# TODO: Add authentication middleware
# TODO: Add request validation middleware
# TODO: Add rate limiting middleware
# TODO: Add API versioning
# TODO: Add response caching

async def get_entry_service() -> AsyncGenerator[EntryService, None]:
    async with PostgresDB() as db:
        yield EntryService(db)


# One summary service for the whole app, created on first use
_summary_service: SummaryService | None = None


def get_summary_service() -> SummaryService:
    """Gives the endpoint a ready summary service, or 503 if the AI settings are missing."""
    global _summary_service
    if _summary_service is None:
        try:
            _summary_service = create_summary_service_from_env()
        except SummaryNotConfiguredError:
            raise HTTPException(status_code=503, detail="AI summary is not configured")
    return _summary_service


@router.post("/entries/summary", tags=["ai"])
async def summarize_entries(
    entry_service: EntryService = Depends(get_entry_service),
    summary_service: SummaryService = Depends(get_summary_service),
):
    """Summarize the newest journal entries with the AI model (called by the backend only)."""
    entries = pick_recent(await entry_service.get_all_entries())
    if not entries:
        raise HTTPException(status_code=404, detail="No entries to summarize")
    try:
        summary = await summary_service.summarize(entries)
    except Exception as error:
        # Log only the error type: details stay out of the browser and out of the logs
        logger.error("AI summary failed: %s", type(error).__name__)
        raise HTTPException(status_code=502, detail="The AI summary is temporarily unavailable")
    return {"summary": summary, "entries_used": len(entries)}


@router.post("/entries")
async def create_entry(entry_data: EntryCreate, entry_service: EntryService = Depends(get_entry_service)):
    """Create a new journal entry."""
    try:
        # Create the full entry with auto-generated fields 
        entry = Entry(
            work=entry_data.work,
            struggle=entry_data.struggle, 
            intention=entry_data.intention
        )
        
        # Store the entry in the database
        created_entry = await entry_service.create_entry(entry.model_dump())
        
        # Return success response (FastAPI handles datetime serialization automatically)
        return {
            "detail": "Entry created successfully", 
            "entry": created_entry
        }
    except Exception as e:
        raise HTTPException(status_code=400, detail=f"Error creating entry: {str(e)}")

# Implements GET /entries endpoint to list all journal entries
# Example response: [{"id": "123", "work": "...", "struggle": "...", "intention": "..."}]
@router.get("/entries")
async def get_all_entries(entry_service: EntryService = Depends(get_entry_service)):
    """Get all journal entries."""
    result = await entry_service.get_all_entries()
    return {"entries": result, "count": len(result)}

@router.get("/entries/{entry_id}")
async def get_entry(request: Request, entry_id: str, entry_service: EntryService = Depends(get_entry_service)):
    """Get a single journal entry by ID."""
    result = await entry_service.get_entry(entry_id)
    if not result:
        raise HTTPException(status_code=404, detail="Entry not found")
    
    return result

@router.patch("/entries/{entry_id}")
async def update_entry(entry_id: str, entry_update: EntryUpdate, entry_service: EntryService = Depends(get_entry_service)):
    """Update a journal entry: only the fields that are sent change."""
    changes = entry_update.model_dump(exclude_none=True)
    if not changes:
        raise HTTPException(status_code=400, detail="Nothing to update")
    result = await entry_service.update_entry(entry_id, changes)
    if not result:
    
        raise HTTPException(status_code=404, detail="Entry not found")
    
    return result

@router.delete("/entries/{entry_id}")
async def delete_entry(entry_id: str, entry_service: EntryService = Depends(get_entry_service)):
    """Delete a specific journal entry."""
    # Check if entry exists first
    existing_entry = await entry_service.get_entry(entry_id)
    if not existing_entry:
        raise HTTPException(status_code=404, detail="Entry not found")
    
    # Delete the entry
    await entry_service.delete_entry(entry_id)
    
    return {"detail": "Entry deleted successfully", "entry_id": entry_id}

@router.delete("/entries")
async def delete_all_entries(entry_service: EntryService = Depends(get_entry_service)):
    """Delete all journal entries"""
    await entry_service.delete_all_entries()
    return {"detail": "All entries deleted"}