defmodule ExICE.Priv.CandidateTest do
  use ExUnit.Case, async: true

  alias ExICE.Priv.Candidate

  test "priority/3" do
    {local_preferences1, prio1} = Candidate.priority(%{}, {192, 168, 0, 1}, :host)

    assert map_size(local_preferences1) == 1
    assert Map.has_key?(local_preferences1, {192, 168, 0, 1})

    # is idempotent
    {^local_preferences1, ^prio1} =
      Candidate.priority(local_preferences1, {192, 168, 0, 1}, :host)

    {local_preferences2, prio2} = Candidate.priority(local_preferences1, {192, 168, 0, 2}, :host)
    assert map_size(local_preferences2) == 2
    assert Map.has_key?(local_preferences2, {192, 168, 0, 1})
    assert Map.has_key?(local_preferences2, {192, 168, 0, 2})
    assert prio2 != prio1

    # the same base address that created srflx candidate
    {^local_preferences2, prio3} =
      Candidate.priority(local_preferences2, {192, 168, 0, 1}, :srflx)

    assert prio3 < prio2
    assert prio3 < prio1

    # the same base address that created relay candidate
    {^local_preferences2, prio4} =
      Candidate.priority(local_preferences2, {192, 168, 0, 1}, :relay)

    assert prio4 < prio3

    # the same base address that created prflx candidate
    {^local_preferences2, prio5} =
      Candidate.priority(local_preferences2, {192, 168, 0, 1}, :prflx)

    assert prio5 < prio1
    assert prio5 < prio2
    assert prio5 > prio3
  end

  test "priority/3 with unknown base address generates new preference" do
    # When a connectivity check succeeds through a TURN relay, the base_address
    # is the relay's allocated IP (e.g. a Cloudflare TURN server), which won't be
    # in local_preferences (only physical interface IPs are there).
    # priority/3 must handle this gracefully instead of crashing.
    local_preferences = %{{192, 168, 0, 1} => 12780, {172, 16, 0, 2} => 28272}
    turn_relay_address = {104, 30, 147, 95}

    {updated_preferences, priority} =
      Candidate.priority(local_preferences, turn_relay_address, :prflx)

    assert is_integer(priority)
    assert priority > 0
    assert Map.has_key?(updated_preferences, turn_relay_address)
    assert map_size(updated_preferences) == 3
    # original preferences are preserved
    assert updated_preferences[{192, 168, 0, 1}] == 12780
    assert updated_preferences[{172, 16, 0, 2}] == 28272
  end
end
