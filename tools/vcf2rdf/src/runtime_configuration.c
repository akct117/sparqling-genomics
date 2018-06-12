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

#include "runtime_configuration.h"
#include "ui.h"
#include "helper.h"
#include "ontology.h"
#include <stdio.h>
#include <stdlib.h>

bool
runtime_configuration_init (void)
{
  config.filter = NULL;
  config.keep = NULL;
  config.input_file = NULL;
  config.reference = NULL;
  config.caller = NULL;
  config.output_format = NULL;
  config.non_unique_variant_counter = 0;
  config.genotype_counter = 0;
  config.info_field_indexes = NULL;
  config.info_field_indexes_len = 0;
  config.info_field_indexes_blocks = 0;
  config.format_field_indexes = NULL;
  config.format_field_indexes_len = 0;
  config.format_field_indexes_blocks = 0;
  config.header_only = false;
  config.show_progress_info = false;

  return true;
}

bool
runtime_configuration_redland_init (void)
{
  config.raptor_world      = raptor_new_world();
  config.raptor_serializer = raptor_new_serializer (config.raptor_world,
                                                    config.output_format);

  if (!config.raptor_world || !config.raptor_serializer)
    return (ui_print_redland_error () == 0);

  raptor_serializer_start_to_file_handle (config.raptor_serializer, NULL, stdout);
  if (!ontology_init (&(config.ontology)))
    return (ui_print_redland_error () == 0);

  return true;
}

void
runtime_configuration_redland_free (void)
{
  /* Free the Redland-allocated memory. */
  runtime_configuration_redland_free ();
  ontology_free (config.ontology);
}

void
runtime_configuration_free (void)
{
  /* Free caches. */
  if (config.info_field_indexes != NULL)
    {
      free (config.info_field_indexes);
      config.info_field_indexes = NULL;
    }
}

bool
generate_variant_id (char *variant_id)
{
  int32_t bytes_written;
  bytes_written = snprintf (variant_id, 16, "UV%010u",
                            config.non_unique_variant_counter);

  config.non_unique_variant_counter++;
  return (bytes_written > 0);
}

bool
generate_genotype_id (char *genotype_id)
{
  int32_t bytes_written;
  bytes_written = snprintf (genotype_id, 16, "GT%010u",
                            config.genotype_counter);

  config.genotype_counter++;
  return (bytes_written > 0);
}
