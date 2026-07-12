import pytest
from clamp import clamp


def test_inside_range():
    assert clamp(5, 0, 10) == 5


def test_below_range():
    assert clamp(-3, 0, 10) == 0


def test_above_range():
    assert clamp(99, 0, 10) == 10


def test_low_boundary_inclusive():
    assert clamp(0, 0, 10) == 0


def test_high_boundary_inclusive():
    assert clamp(10, 0, 10) == 10


def test_inverted_range_raises():
    with pytest.raises(ValueError):
        clamp(5, 10, 0)
