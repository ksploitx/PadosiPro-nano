from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.future import select

from app.deps import get_db, get_current_user
from app.models import User, Task, TaskSelection
from app.schemas import TaskResponse, TaskSelectionRequest

router = APIRouter(prefix="/tasks", tags=["tasks"])


@router.get("/catalogue", response_model=list[TaskResponse])
async def get_catalogue(db: AsyncSession = Depends(get_db)):
    """Return all available tasks (no auth required)."""
    result = await db.execute(select(Task).order_by(Task.category, Task.name))
    return result.scalars().all()


@router.put("/selection", response_model=list[TaskResponse])
async def replace_selection(
    body: TaskSelectionRequest,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """
    Full-replace the user's task selection.
    Rejects: empty list (422), any unknown task id (422).
    """
    # Validate every submitted id exists in tasks table
    result = await db.execute(
        select(Task).where(Task.id.in_(body.task_ids))
    )
    found_tasks = result.scalars().all()
    found_ids = {t.id for t in found_tasks}

    unknown = [tid for tid in body.task_ids if tid not in found_ids]
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

    for task_id in body.task_ids:
        db.add(TaskSelection(user_id=current_user.id, task_id=task_id))

    await db.commit()

    # Return the full task objects in the same order as submitted
    ordered = sorted(found_tasks, key=lambda t: body.task_ids.index(t.id))
    return ordered


@router.get("/selection", response_model=list[TaskResponse])
async def get_selection(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Return the authenticated user's currently selected tasks (empty list if none)."""
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

    return [tasks_by_id[tid] for tid in task_ids if tid in tasks_by_id]
