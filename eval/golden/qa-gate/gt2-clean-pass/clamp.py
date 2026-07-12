def clamp(value: int, low: int, high: int) -> int:
    """Clamp value into the inclusive range [low, high].

    low and high are both inclusive. Raise ValueError if low > high.
    """
    if low > high:
        raise ValueError("low must be <= high")
    if value < low:
        return low
    if value > high:
        return high
    return value
