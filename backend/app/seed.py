"""
Seed the tasks table with initial data.
Run with:  python -m app.seed
"""
import asyncio
import uuid

from sqlalchemy.future import select
from app.database import engine, Base, AsyncSessionLocal
from app.models import Task


TASKS = [
    # ── Home Services ──────────────────────────────────────────────────────────
    {
        "category": "Home Services",
        "name": "House Cleaning",
        "description": "Regular cleaning of all rooms, dusting, mopping, and sanitation.",
    },
    {
        "category": "Home Services",
        "name": "Deep Cleaning",
        "description": "Thorough scrubbing of kitchen, bathrooms, and hard-to-reach areas.",
    },
    {
        "category": "Home Services",
        "name": "Plumbing Repairs",
        "description": "Fix leaking taps, pipes, blocked drains, and water heater issues.",
    },
    {
        "category": "Home Services",
        "name": "Electrical Work",
        "description": "Wiring fixes, fan installation, switchboard repairs, and safety checks.",
    },
    {
        "category": "Home Services",
        "name": "AC Servicing",
        "description": "Air-conditioner cleaning, gas refill, and routine maintenance.",
    },
    {
        "category": "Home Services",
        "name": "Pest Control",
        "description": "Treatment for cockroaches, ants, mosquitoes, and rodents.",
    },

    # ── Errands & Daily Tasks ─────────────────────────────────────────────────
    {
        "category": "Errands & Daily Tasks",
        "name": "Grocery Shopping",
        "description": "Pick up your grocery list from the nearest supermarket or local market.",
    },
    {
        "category": "Errands & Daily Tasks",
        "name": "Laundry & Ironing",
        "description": "Collect, wash, dry, iron, and deliver clothes back to your door.",
    },
    {
        "category": "Errands & Daily Tasks",
        "name": "Bill Payments",
        "description": "Pay electricity, water, gas, and other utility bills on your behalf.",
    },
    {
        "category": "Errands & Daily Tasks",
        "name": "Medicine Pickup",
        "description": "Collect prescriptions and over-the-counter medicines from the pharmacy.",
    },
    {
        "category": "Errands & Daily Tasks",
        "name": "Courier & Document Drop",
        "description": "Drop off or collect parcels, documents, and packages from any office.",
    },
    {
        "category": "Errands & Daily Tasks",
        "name": "Car Wash & Fuelling",
        "description": "Get your car cleaned, vacuumed, and tank topped up.",
    },

    # ── Business Support ──────────────────────────────────────────────────────
    {
        "category": "Business Support",
        "name": "Office Supply Restocking",
        "description": "Procure stationery, printer cartridges, and consumables for your office.",
    },
    {
        "category": "Business Support",
        "name": "Document Printing & Binding",
        "description": "Print, laminate, or bind reports, agreements, and presentations.",
    },
    {
        "category": "Business Support",
        "name": "Bank & Government Errands",
        "description": "Visit bank branches or government offices to submit or collect documents.",
    },
    {
        "category": "Business Support",
        "name": "Parcel Dispatch",
        "description": "Pack and ship client orders or business parcels via courier services.",
    },

    # ── Personal Care & Lifestyle ─────────────────────────────────────────────
    {
        "category": "Personal Care & Lifestyle",
        "name": "Salon Appointment Booking",
        "description": "Schedule haircuts, facials, and grooming sessions at your preferred salon.",
    },
    {
        "category": "Personal Care & Lifestyle",
        "name": "Meal Planning & Tiffin Arrangement",
        "description": "Source and coordinate daily home-cooked or tiffin meals for you.",
    },
    {
        "category": "Personal Care & Lifestyle",
        "name": "Pet Care",
        "description": "Dog walking, grooming appointments, and pet-supply pickup.",
    },
    {
        "category": "Personal Care & Lifestyle",
        "name": "Event & Gift Arrangements",
        "description": "Plan birthday surprises, buy gifts, and arrange flower or cake deliveries.",
    },
    {
        "category": "Personal Care & Lifestyle",
        "name": "Travel Booking Assistance",
        "description": "Research and book flights, trains, hotels, and cabs for your trips.",
    },
]


async def seed():
    # Ensure tables exist
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)

    async with AsyncSessionLocal() as session:
        # Check how many tasks already exist
        result = await session.execute(select(Task))
        existing = result.scalars().all()
        existing_names = {t.name for t in existing}

        new_tasks = [
            Task(
                id=str(uuid.uuid4()),
                name=t["name"],
                category=t["category"],
                description=t["description"],
            )
            for t in TASKS
            if t["name"] not in existing_names
        ]

        if not new_tasks:
            total = len(existing)
            print(f"Tasks table already seeded — {total} task(s) present. Nothing to do.")
            return

        session.add_all(new_tasks)
        await session.commit()
        print(f"Seeded {len(new_tasks)} new task(s). Total tasks in DB: {len(existing) + len(new_tasks)}.")


if __name__ == "__main__":
    asyncio.run(seed())
