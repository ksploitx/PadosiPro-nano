from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.future import select

from app.deps import get_db, get_current_user
from app.models import User, Task, TaskSelection
from app.schemas import TaskResponse, TaskSelectionCreate, TaskSelectionUpdate, TaskSelectionResponse

router = APIRouter(prefix="/tasks", tags=["tasks"])


@router.get("/catalogue", response_model=list[TaskResponse])
async def get_catalogue(db: AsyncSession = Depends(get_db)):
    """Return all available tasks (no auth required)."""
    result = await db.execute(select(Task).order_by(Task.category, Task.name))
    return result.scalars().all()


@router.post("/selection", response_model=TaskSelectionResponse)
async def add_selection(
    body: TaskSelectionCreate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """
    Adds a new task selection for the current user.
    If the task is already selected, updates its time/note (upsert).
    422 if task_id doesn't exist in the catalogue.
    """
    # Check if task exists
    task_result = await db.execute(select(Task).where(Task.id == body.task_id))
    task = task_result.scalars().first()
    if not task:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail=f"Unknown task id: {body.task_id}",
        )

    # Check if selection already exists
    existing_result = await db.execute(
        select(TaskSelection)
        .where(TaskSelection.user_id == current_user.id)
        .where(TaskSelection.task_id == body.task_id)
    )
    selection = existing_result.scalars().first()

    if selection:
        # Upsert
        selection.requested_time = body.requested_time
        selection.note = body.note
    else:
        selection = TaskSelection(
            user_id=current_user.id,
            task_id=body.task_id,
            requested_time=body.requested_time,
            note=body.note,
        )
        db.add(selection)

    await db.commit()
    await db.refresh(selection)

    return TaskSelectionResponse(
        id=task.id,
        name=task.name,
        category=task.category,
        description=task.description,
        requested_time=selection.requested_time,
        note=selection.note,
    )


@router.patch("/selection/{task_id}", response_model=TaskSelectionResponse)
async def update_selection(
    task_id: str,
    body: TaskSelectionUpdate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """
    Updates an existing task selection for the current user.
    404 if not found.
    """
    result = await db.execute(
        select(TaskSelection)
        .where(TaskSelection.user_id == current_user.id)
        .where(TaskSelection.task_id == task_id)
    )
    selection = result.scalars().first()

    if not selection:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Task selection not found",
        )

    selection.requested_time = body.requested_time
    selection.note = body.note
    await db.commit()
    await db.refresh(selection)

    task_result = await db.execute(select(Task).where(Task.id == task_id))
    task = task_result.scalars().first()

    return TaskSelectionResponse(
        id=task.id,
        name=task.name,
        category=task.category,
        description=task.description,
        requested_time=selection.requested_time,
        note=selection.note,
    )


@router.delete("/selection/{task_id}", status_code=status.HTTP_204_NO_CONTENT)
async def remove_selection(
    task_id: str,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """
    Removes a task selection for the current user.
    404 if not found.
    """
    result = await db.execute(
        select(TaskSelection)
        .where(TaskSelection.user_id == current_user.id)
        .where(TaskSelection.task_id == task_id)
    )
    selection = result.scalars().first()

    if not selection:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Task selection not found",
        )

    await db.delete(selection)
    await db.commit()
    return


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
