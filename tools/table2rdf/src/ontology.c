/*
 * Copyright (C) 2018  Roel Janssen <roel@gnu.org>
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

#include "ontology.h"
#include "runtime_configuration.h"
#include <stdlib.h>

/* The following macros simplify the initialization code of the ontology.
 * They are specific for the variables names used in 'ontology_init', so
 * don't use them outside of 'ontology_init'.
 */
#define register_prefix(index, uri, prefix) ontology->prefixes[index] = \
  raptor_new_uri (config.raptor_world, (unsigned char *)uri);           \
  raptor_serializer_set_namespace (config.raptor_serializer,            \
                                   ontology->prefixes[index],           \
                                   (unsigned char *)prefix)

#define define_xsd(index, suffix)                                       \
  ontology->xsds[index] =                                               \
  raptor_new_uri_relative_to_base (config.raptor_world,                 \
                                   ontology->prefixes[PREFIX_XSD],      \
                                   (unsigned char *)suffix)

void
define_class (ontology_t *ontology, int32_t index, int32_t prefix, char *suffix)
{
  raptor_uri *uri = raptor_new_uri_relative_to_base (config.raptor_world,
                                                     ontology->prefixes[prefix],
                                                     (unsigned char *)suffix);

  ontology->classes[index] = raptor_new_term_from_uri (config.raptor_world, uri);
  raptor_free_uri (uri);
}

void
define_predicate (ontology_t *ontology, int32_t index, int32_t prefix, char *suffix)
{
  raptor_uri *uri = raptor_new_uri_relative_to_base (config.raptor_world,
                                                     ontology->prefixes[prefix],
                                                     (unsigned char *)suffix);

  ontology->predicates[index] = raptor_new_term_from_uri (config.raptor_world, uri);
  raptor_free_uri (uri);
}

bool
ontology_init (ontology_t **ontology_ptr)
{
  if (!ontology_ptr) return false;

  ontology_t *ontology = calloc (1, sizeof (ontology_t));
  if (!ontology) return false;

  ontology->prefixes_length = 10;
  ontology->prefixes_static_length = 10;
  ontology->prefixes = calloc (ontology->prefixes_length, sizeof (raptor_uri*));

  register_prefix (PREFIX_BASE,              STR_PREFIX_BASE,              "");
  register_prefix (PREFIX_MASTER,            STR_PREFIX_MASTER,            "sg");
  register_prefix (PREFIX_SAMPLE,            STR_PREFIX_SAMPLE,            "sample");
  register_prefix (PREFIX_ORIGIN,            STR_PREFIX_ORIGIN,            "orig");
  register_prefix (PREFIX_ROW,               STR_PREFIX_ROW,               "row");
  register_prefix (PREFIX_COLUMN,            STR_PREFIX_COLUMN,            "col");
  register_prefix (PREFIX_RDF,               STR_PREFIX_RDF,               "rdf");
  register_prefix (PREFIX_RDFS,              STR_PREFIX_RDFS,              "rdfs");
  register_prefix (PREFIX_XSD,               STR_PREFIX_XSD,               "xsd");
  register_prefix (PREFIX_OWL,               STR_PREFIX_OWL,               "owl");

  int32_t initialized_prefixes = 0;
  for (; initialized_prefixes < ontology->prefixes_length; initialized_prefixes++)
    if (!ontology->prefixes[initialized_prefixes]) break;

  ontology->classes_length = 5;
  ontology->classes = calloc (ontology->classes_length, sizeof (raptor_term*));

  define_class (ontology, CLASS_RDF_TYPE,               PREFIX_RDF,    "#type");
  define_class (ontology, CLASS_ORIGIN,                 PREFIX_MASTER, "Origin");
  define_class (ontology, CLASS_SAMPLE,                 PREFIX_MASTER, "Sample");
  define_class (ontology, CLASS_COLUMN,                 PREFIX_BASE,   "Column");
  define_class (ontology, CLASS_ROW,                    PREFIX_BASE,   "Row");

  int32_t initialized_classes = 0;
  for (; initialized_classes < ontology->classes_length; initialized_classes++)
    if (!ontology->classes[initialized_classes]) break;

  ontology->predicates_length = 8;
  ontology->predicates = calloc (ontology->predicates_length, sizeof (raptor_term*));

  define_predicate (ontology, PREDICATE_RDF_TYPE,        PREFIX_RDF,    "#type");
  define_predicate (ontology, PREDICATE_CONVERTED_BY,    PREFIX_MASTER, "convertedBy");
  define_predicate (ontology, PREDICATE_VERSION_INFO,    PREFIX_OWL,    "#versionInfo");
  define_predicate (ontology, PREDICATE_FILENAME,        PREFIX_MASTER, "filename");
  define_predicate (ontology, PREDICATE_ORIGINATED_FROM, PREFIX_MASTER, "originatedFrom");
  define_predicate (ontology, PREDICATE_FOUND_IN,        PREFIX_MASTER, "foundIn");
  define_predicate (ontology, PREDICATE_LABEL,           PREFIX_RDFS,   "#label");
  define_predicate (ontology, PREDICATE_POSITION,        PREFIX_BASE,   "position");

  int32_t initialized_predicates = 0;
  for (; initialized_predicates < ontology->predicates_length; initialized_predicates++)
    if (!ontology->predicates[initialized_predicates]) break;

  ontology->xsds_length = 4;
  ontology->xsds = calloc (ontology->xsds_length, sizeof (raptor_uri*));
  define_xsd (XSD_STRING,  "#string");
  define_xsd (XSD_INTEGER, "#integer");
  define_xsd (XSD_FLOAT,   "#float");
  define_xsd (XSD_BOOLEAN, "#boolean");
  
  int32_t initialized_xsds = 0;
  for (; initialized_xsds < ontology->xsds_length; initialized_xsds++)
    if (!ontology->classes[initialized_xsds]) break;

  if ((initialized_predicates == ontology->predicates_length) &&
      (initialized_classes    == ontology->classes_length)    &&
      (initialized_prefixes   == ontology->prefixes_length)   &&
      (initialized_xsds       == ontology->xsds_length))
    {
      *ontology_ptr = ontology;
      return true;
    }
  else
    {
      free (ontology);
      *ontology_ptr = NULL;
      return false;
    }
}

void
ontology_free (ontology_t *ontology)
{
  int32_t index;
  for (index = 0; index < ontology->prefixes_length; index++)
    {
      raptor_free_uri (ontology->prefixes[index]);
      ontology->prefixes[index] = NULL;
    }

  for (index = 0; index < ontology->classes_length; index++)
    {
      raptor_free_term (ontology->classes[index]);
      ontology->classes[index] = NULL;
    }

  for (index = 0; index < ontology->predicates_length; index++)
    {
      raptor_free_term (ontology->predicates[index]);
      ontology->predicates[index] = NULL;
    }

  for (index = 0; index < ontology->xsds_length; index++)
    {
      raptor_free_uri (ontology->xsds[index]);
      ontology->xsds[index] = NULL;
    }

  free (ontology->prefixes);
  ontology->prefixes = NULL;
  ontology->prefixes_length = 0;

  free (ontology->classes);
  ontology->classes = NULL;
  ontology->classes_length = 0;

  free (ontology->predicates);
  ontology->predicates = NULL;
  ontology->predicates_length = 0;

  free (ontology->xsds);
  ontology->xsds = NULL;
  ontology->xsds_length = 0;

  free (ontology);
}

raptor_term*
term (int32_t index, char *suffix)
{
  raptor_term *term;
  raptor_uri *uri;
  uri = raptor_new_uri_relative_to_base (config.raptor_world,
                                         config.ontology->prefixes[index],
                                         (const unsigned char *)suffix);

  term = raptor_new_term_from_uri (config.raptor_world, uri);
  raptor_free_uri (uri);
  return term;
}
