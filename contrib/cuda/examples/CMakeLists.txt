build_lib_example(
    NAME cuda-example
    SOURCE_FILES cuda-example.cc
    LIBRARIES_TO_LINK ${libcuda}
)
