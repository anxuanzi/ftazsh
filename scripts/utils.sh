#!/bin/bash
# Utility functions for ftazsh installation

# Print a regular message
print_message() {
    echo -e "🔵  $1"
}

# Print a success message
print_success() {
    echo -e "✅  $1"
}

# Print an error message
print_error() {
    echo -e "❌  $1" >&2
}