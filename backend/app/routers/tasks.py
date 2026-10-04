from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.future import select

from app.deps import get_db, get_current_user
from app.models import User, Task, TaskSelection
from app.schemas import TaskResponse, TaskSelectionRequest, TaskSelectionResponse

router = APIRouter(prefix="/tasks", tags=["tasks"])


@router.get("/catalogue", response_model=list[TaskResponse])
async def get_catalogue(db: AsyncSession = Depends(get_db)):
    """Return all available tasks (no auth required)."""
    result = await db.execute(select(Task).order_by(Task.category, Task.name))
    return result.scalars().all()


@router.put("/selection", response_model=list[TaskSelectionResponse])
async def replace_selection(
    body: TaskSelectionRequest,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """
    Full-replace the user's task selection.
    Rejects: empty selections list (422), any unknown task id (422).
    Each item may carry an optional requested_time and/or note.
    """
    submitted_ids = [item.task_id for item in body.selections]

    # Validate every submitted id exists in tasks table
    result = await db.execute(
        select(Task).where(Task.id.in_(submitted_ids))
    )
    found_tasks = result.scalars().all()
    found_ids = {t.id for t in found_tasks}
    tasks_by_id = {t.id: t for t in found_tasks}

    unknown = [tid for tid in submitted_ids if tid not in found_ids]
    if unknown:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail=f"Unknown task id(s): {unknown}",
        )

    # Full replace: delete existing selections then insert fresh ones
    existing = await db.execute(
        select(TaskSelection).where(TaskSelection.user_id == current_user.id)
    )
    for sel in existing.scalars().all():
        await db.delete(sel)

    new_selections: list[TaskSelection] = []
    for item in body.selections:
        sel = TaskSelection(
            user_id=current_user.id,
            task_id=item.task_id,
            requested_time=item.requested_time,
            note=item.note,
        )
        db.add(sel)
        new_selections.append(sel)

    await db.commit()

    # Refresh each selection so SQLAlchemy populates any server-side defaults
    for sel in new_selections:
        await db.refresh(sel)

    # Build response: merge task fields with selection metadata, preserving order
    response = []
    for item, sel in zip(body.selections, new_selections):
        task = tasks_by_id[item.task_id]
        response.append(TaskSelectionResponse(
            id=task.id,
            name=task.name,
            category=task.category,
            description=task.description,
            requested_time=sel.requested_time,
            note=sel.note,
        ))

    return response


@router.get("/selection", response_model=list[TaskSelectionResponse])
async def get_selection(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Return the authenticated user's currently selected tasks with time/note."""
    result = await db.execute(
        select(TaskSelection)
        .where(TaskSelection.user_id == current_user.id)
        .order_by(TaskSelection.created_at)
    )
    selections = result.scalars().all()

    if not selections:
        return []

    task_ids = [s.task_id for s in selections]
    task_result = await db.execute(
        select(Task).where(Task.id.in_(task_ids))
    )
    tasks_by_id = {t.id: t for t in task_result.scalars().all()}

    response = []
    for sel in selections:
        task = tasks_by_id.get(sel.task_id)
        if task is None:
            continue
        response.append(TaskSelectionResponse(
            id=task.id,
            name=task.name,
            category=task.category,
            description=task.description,
            requested_time=sel.requested_time,
            note=sel.note,
        ))

    return response
