#!/usr/bin/env python3

import sys
import argparse
from copy import deepcopy

from gffpal.gff import GFF, GFFRecord, Strand


def cli(prog, args):
    parser = argparse.ArgumentParser(
        prog=prog,
        description=""" """
    )

    parser.add_argument(
        "infile",
        type=argparse.FileType('r'),
        help=".",
    )

    parser.add_argument(
        "-s", "--source",
        type=str,
        default="EAhelitron",
        help="The source.",
    )

    parser.add_argument(
        "-o", "--outfile",
        default=sys.stdout,
        type=argparse.FileType('w'),
        help="Output GFF3 file. Default stdout.",
    )

    return parser.parse_args(args)


def main():
    args = cli(sys.argv[0], sys.argv[1:])

    rows = []
    for line in args.infile:
        if line.startswith("#"):
            continue
        record = GFFRecord.parse(line)
        record.attributes.id = record.attributes.name
        record.attributes.name = None
        record.attributes.custom = {}
        rows.append(record)

    gff = GFF(rows)
    gff.infer_missing_parents()

    counter = 1

    for mrna in gff.select_type("mRNA"):
        if len(mrna.children) < 2:
            continue

        region = deepcopy(mrna)
        region.type = "repeat_region"
        region.attributes.id = f"repeat_region{counter}"
        region.attributes.ontology_term = ["SO:0000657"],

        mrna.type = "helitron"
        mrna.parents = [region]
        mrna.attributes.parent = [region.attributes.id]
        mrna.attributes.id = f"helitron{counter}"
        mrna.attributes.ontology_term = ["SO:0000544", "SO:helitron"]
        mrna.attributes.custom = {}

        flank3 = [c for c in mrna.children
                  if c.attributes.id.endswith(".3")]
        if not flank3:
            continue
        else:
            flank3 = flank3[0]

        flank5 = [c for c in mrna.children
                  if c.attributes.id.endswith(".5.1")]

        if not flank5:
            continue
        else:
            flank5 = flank5[0]

        flank3.type = "three_prime_flanking_region"
        flank3.attributes.ontology_term = [
            "SO:0001417",
            "SO:three_prime_flanking_region",
            "SO:0000364",
            "SO:transposable_element_flanking_region"
        ]
        flank3.attributes.id = None
        flank3.attributes.parent = [mrna.attributes.id]

        flank5.type = "five_prime_flanking_region"
        flank5.attributes.ontology_term = [
            "SO:0001416",
            "SO:five_prime_flanking_region",
            "SO:0000364",
            "SO:transposable_element_flanking_region"
        ]
        flank5.attributes.id = None
        flank5.attributes.parent = [mrna.attributes.id]

        mrna.source = flank5.source

        print(region, file=args.outfile)
        print(mrna, file=args.outfile)
        if mrna.strand == Strand.MINUS:
            print(flank3, file=args.outfile)
            print(flank5, file=args.outfile)
        else:
            print(flank5, file=args.outfile)
            print(flank3, file=args.outfile)

        counter += 1

    return


if __name__ == "__main__":
    main()
