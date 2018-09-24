/* Copyright (C) 2018  Roel Janssen <roel@gnu.org>
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

#ifndef ONTOLOGY_H
#define ONTOLOGY_H

#include <stdbool.h>
#include <stdint.h>
#include <raptor2.h>
#include <htslib/sam.h>
#include <htslib/vcf.h>

/* These string constants can be used to concatenate strings at compile-time. */
#define URI_W3            "http://www.w3.org"
#define URI_BIOSEMANTICS  "http://rdf.biosemantics.org"
#define URI_ASSEMBLIES    URI_BIOSEMANTICS "/data/genomeassemblies"
#define URI_ONTOLOGY      "http://sparqling-genomics/bam2rdf"
#define URI_MASTER        "http://sparqling-genomics"

#define STR_PREFIX_MASTER              URI_MASTER "/"
#define STR_PREFIX_BASE                URI_ONTOLOGY "/"
#define STR_PREFIX_SAMPLE              URI_MASTER "/Sample/"
#define STR_PREFIX_BAM_HEADER          URI_ONTOLOGY "/HeaderItem/"
#define STR_PREFIX_BAM_REFERENCE_SEQ   URI_ONTOLOGY "/ReferenceSequence/"
#define STR_PREFIX_BAM_READ_GROUP      URI_ONTOLOGY "/ReadGroup/"
#define STR_PREFIX_BAM_PROGRAM         URI_ONTOLOGY "/Program/"
#define STR_PREFIX_BAM_COMMENT         URI_ONTOLOGY "/Comment/"
#define STR_PREFIX_BAM_READ            URI_ONTOLOGY "/SequencingRead/"
#define STR_PREFIX_SEQUENCE            URI_ONTOLOGY "/Sequence/"
#define STR_PREFIX_ORIGIN              URI_MASTER "/Origin/"
#define STR_PREFIX_RDF                 URI_W3 "/1999/02/22-rdf-syntax-ns#"
#define STR_PREFIX_RDFS                URI_W3 "/2000/01/rdf-schema#"
#define STR_PREFIX_OWL                 URI_W3 "/2002/07/owl#"
#define STR_PREFIX_XSD                 URI_W3 "/2001/XMLSchema#"
#define STR_PREFIX_FALDO               "http://biohackathon.org/resource/faldo#"
#define STR_PREFIX_HG19                URI_ASSEMBLIES "/hg19#"
#define STR_PREFIX_HG19_CHR            URI_ASSEMBLIES "/hg19#chr"

typedef enum
{
  PREFIX_BASE = 0,
  PREFIX_MASTER,
  PREFIX_SAMPLE,
  PREFIX_BAM_HEADER,
  PREFIX_BAM_REFERENCE_SEQ,
  PREFIX_BAM_READ_GROUP,
  PREFIX_BAM_PROGRAM,
  PREFIX_BAM_COMMENT,
  PREFIX_BAM_READ,
  PREFIX_SEQUENCE,
  PREFIX_ORIGIN,
  PREFIX_RDF,
  PREFIX_RDFS,
  PREFIX_OWL,
  PREFIX_XSD,
  PREFIX_FALDO,
  PREFIX_HG19,
  PREFIX_HG19_CHR,
  PREFIX_UNKNOWN
} ontology_prefix;

typedef enum
{
  CLASS_RDF_TYPE = 0,
  CLASS_ORIGIN,
  CLASS_BAM_HEADER,
  CLASS_BAM_REFERENCE_SEQ,
  CLASS_BAM_READ_GROUP,
  CLASS_BAM_PROGRAM,
  CLASS_BAM_COMMENT,
  CLASS_SAMPLE,
  CLASS_BAM_READ,
  CLASS_UNKNOWN
} ontology_class;

typedef struct
{
  raptor_term **classes;
  raptor_uri  **prefixes;
  raptor_uri **xsds;
  int32_t     classes_length;
  int32_t     prefixes_length;
  int32_t     xsds_length;
} ontology_t;

#define XSD_STRING              BCF_HT_STR
#define XSD_INTEGER             BCF_HT_INT
#define XSD_FLOAT               BCF_HT_REAL
#define XSD_BOOLEAN             BCF_HT_FLAG

bool ontology_init (ontology_t **ontology_ptr);
void ontology_free (ontology_t *ontology);

raptor_term* term (int32_t index, char *suffix);

/* The following marcros can be used to construct terms (nodes) and URIs.
 * These assume 'config.raptor_world', 'config.uris', 'config.ontology',
 * and 'config.raptor_serializer' exist and have been initialized.
 */
#define uri(index, suffix)                                      \
  raptor_new_uri_relative_to_base (config.raptor_world,         \
                                   config.uris[index],          \
                                   str)

/* TODO: Possibly wrap this in raptor_term_copy. */
#define class(index)                                            \
  raptor_term_copy (config.ontology->classes[index])

#define literal(str, datatype)                                  \
  raptor_new_term_from_literal                                  \
  (config.raptor_world, (unsigned char *)str,                   \
   config.ontology->xsds[datatype],                             \
   NULL)

#define register_statement(stmt)                                \
  raptor_serializer_serialize_statement                         \
  (config.raptor_serializer, stmt);                             \
  raptor_free_statement (stmt)


#endif  /* ONTOLOGY_H */