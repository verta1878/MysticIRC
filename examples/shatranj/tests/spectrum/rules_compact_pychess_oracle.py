#!/usr/bin/env python3
import argparse
import csv
import random
import subprocess
import sys
from pathlib import Path

extra_site = Path('C:/tmp/netchesszx-pychess-oracle')
if extra_site.exists():
    sys.path.insert(0, str(extra_site))

try:
    import chess
    import chess.pgn
except ImportError as exc:
    raise SystemExit('python-chess missing: install package "chess" first') from exc

STANDARD = [
    ('startpos',
     'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1', 4),
    ('kiwipete',
     'r3k2r/p1ppqpb1/bn2pnp1/3PN3/1p2P3/2N2Q1p/PPPBBPPP/R3K2R w KQkq - 0 1', 3),
    ('promotion-castle',
     'r3k2r/Pppp1ppp/1b3nbN/nP6/BBP1P3/q4N2/Pp1P2PP/R2Q1RK1 w kq - 0 1', 3),
    ('promotion-checks',
     'rnbq1k1r/pp1Pbppp/2p5/8/2B1P3/8/PPP2PPP/RNBQK1NR b KQ - 1 8', 3),
    ('middlegame-pins',
     'r4rk1/1pp1qppp/p1np1n2/2b1p1B1/2B1P1b1/2NP1N2/PPP2PPP/R2Q1RK1 w - - 0 10', 3),
]


def py_perft(board, depth):
    if depth == 0:
        return 1
    total = 0
    for move in list(board.legal_moves):
        board.push(move)
        total += py_perft(board, depth - 1)
        board.pop()
    return total


def run_compact(exe, args):
    proc = subprocess.run(
        [str(exe), *args],
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        check=False,
    )
    if proc.returncode != 0:
        raise RuntimeError(
            f'compact failed rc={proc.returncode}: {proc.stdout}{proc.stderr}'
        )
    return proc.stdout


def compact_perft(exe, fen, depth):
    out = run_compact(exe, [fen, str(depth)])
    return int(out.strip().splitlines()[-1])


def compact_moves(exe, fen):
    out = run_compact(exe, ['--moves', fen])
    return {line.strip() for line in out.splitlines() if line.strip()}


def py_moves(board):
    return {move.uci() for move in board.legal_moves}


def assert_moves_equal(exe, name, fen):
    board = chess.Board(fen)
    got = compact_moves(exe, fen)
    want = py_moves(board)
    if got != want:
        missing = sorted(want - got)
        extra = sorted(got - want)
        raise AssertionError(
            f'{name}: move set mismatch\n'
            f'fen={fen}\n'
            f'missing={missing[:40]}\n'
            f'extra={extra[:40]}'
        )


def check_position(exe, name, fen, depth):
    board = chess.Board(fen)
    assert_moves_equal(exe, name, fen)
    want = py_perft(board, depth)
    got = compact_perft(exe, fen, depth)
    if got != want:
        raise AssertionError(
            f'{name} depth {depth}: compact={got} python-chess={want} fen={fen}'
        )


def random_reachable_fens(seed, count, max_plies):
    rng = random.Random(seed)
    for index in range(count):
        board = chess.Board()
        plies = rng.randint(0, max_plies)
        for _ in range(plies):
            moves = list(board.legal_moves)
            if not moves:
                break
            board.push(rng.choice(moves))
        yield f'random-{index}', board.fen()


def iter_fen_file(path, limit):
    with open(path, newline='', encoding='utf-8') as handle:
        for index, row in enumerate(csv.reader(handle)):
            if limit is not None and index >= limit:
                break
            if not row or not row[0] or row[0].startswith('#'):
                continue
            for field in row:
                try:
                    chess.Board(field)
                except ValueError:
                    continue
                yield f'{path.name}:{index + 1}', field
                break


def iter_pgn_positions(path, games, max_plies, step):
    with open(path, encoding='utf-8', errors='replace') as handle:
        for game_index in range(games):
            game = chess.pgn.read_game(handle)
            if game is None:
                break
            board = game.board()
            yield f'{path.name}:game-{game_index}:start', board.fen()
            for ply, move in enumerate(game.mainline_moves(), start=1):
                if ply > max_plies:
                    break
                board.push(move)
                if ply % step == 0:
                    yield f'{path.name}:game-{game_index}:ply-{ply}', board.fen()


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--exe', default='build/netchesszx_rules_compact_perft_test.exe')
    parser.add_argument('--random', type=int, default=200)
    parser.add_argument('--random-depth', type=int, default=2)
    parser.add_argument('--max-plies', type=int, default=80)
    parser.add_argument('--seed', type=int, default=20260701)
    parser.add_argument('--fen-file', action='append', default=[])
    parser.add_argument('--fen-limit', type=int, default=None)
    parser.add_argument('--pgn', action='append', default=[])
    parser.add_argument('--pgn-games', type=int, default=100)
    parser.add_argument('--pgn-plies', type=int, default=120)
    parser.add_argument('--pgn-step', type=int, default=1)
    args = parser.parse_args()

    exe = Path(args.exe)
    if not exe.exists():
        raise SystemExit(f'missing compact perft exe: {exe}')
    if args.pgn_step < 1:
        raise SystemExit('--pgn-step must be >= 1')

    checked = 0
    move_sets = 0

    for name, fen, max_depth in STANDARD:
        assert_moves_equal(exe, name, fen)
        move_sets += 1
        for depth in range(1, max_depth + 1):
            check_position(exe, name, fen, depth)
            checked += 1

    for name, fen in random_reachable_fens(args.seed, args.random, args.max_plies):
        assert_moves_equal(exe, name, fen)
        move_sets += 1
        for depth in range(1, args.random_depth + 1):
            check_position(exe, name, fen, depth)
            checked += 1

    for fen_path in map(Path, args.fen_file):
        for name, fen in iter_fen_file(fen_path, args.fen_limit):
            assert_moves_equal(exe, name, fen)
            move_sets += 1

    for pgn_path in map(Path, args.pgn):
        for name, fen in iter_pgn_positions(
            pgn_path, args.pgn_games, args.pgn_plies, args.pgn_step
        ):
            assert_moves_equal(exe, name, fen)
            move_sets += 1

    print(
        f'rules_compact python-chess oracle ok: '
        f'{move_sets} move-set checks, {checked} perft checks'
    )


if __name__ == '__main__':
    main()