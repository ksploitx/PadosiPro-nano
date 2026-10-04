from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.future import select

from app.deps import get_db, get_current_user
from app.models import User, Profile
from app.schemas import ProfileRequest, ProfileResponse

router = APIRouter(prefix="/profile", tags=["profile"])


def _build_response(profile: Profile, user: User) -> ProfileResponse:
    """Merge Profile row + User.email into a ProfileResponse."""
    return ProfileResponse(
        name=profile.name,
        mobile_number=profile.mobile_number,
        address=profile.address,
        business_name=profile.business_name,
        email=user.email,
    )


@router.put("", response_model=ProfileResponse)
async def upsert_profile(
    body: ProfileRequest,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Create or update the authenticated user's profile (full replace)."""
    result = await db.execute(
        select(Profile).where(Profile.user_id == current_user.id)
    )
    profile = result.scalar_one_or_none()

    if profile is None:
        profile = Profile(user_id=current_user.id)
        db.add(profile)

    profile.name = body.name
    profile.mobile_number = body.mobile_number
    profile.address = body.address
    profile.business_name = body.business_name

    # Mark the user as having completed their profile
    current_user.has_completed_profile = 1

    await db.commit()
    await db.refresh(profile)
    return _build_response(profile, current_user)


@router.get("", response_model=ProfileResponse)
async def get_profile(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """
    Return the profile for the authenticated user.
    Returns 404 when no profile exists yet — the mobile app uses this to
    route first-login users to the Profile setup screen.
    """
    result = await db.execute(
        select(Profile).where(Profile.user_id == current_user.id)
    )
    profile = result.scalar_one_or_none()

    if profile is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Profile not found",
        )

    return _build_response(profile, current_user)
