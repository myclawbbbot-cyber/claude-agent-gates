def page_count(total_items: int, per_page: int) -> int:
    """Number of pages needed to display total_items, per_page items per page.

    The final partial page MUST be counted:
    e.g. 10 items at 3 per page -> 4 pages (three full pages + one partial).
    per_page <= 0 must raise ValueError.
    """
    if per_page <= 0:
        raise ValueError("per_page must be positive")
    return total_items // per_page
