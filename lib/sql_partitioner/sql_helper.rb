module SqlPartitioner
  class SQL

    # SQL query will return rows having the following columns:
    #   - TABLE_CATALOG
    #   - TABLE_SCHEMA
    #   - TABLE_NAME
    #   - PARTITION_NAME
    #   - SUBPARTITION_NAME
    #   - PARTITION_ORDINAL_POSITION
    #   - SUBPARTITION_ORDINAL_POSITION
    #   - PARTITION_METHOD
    #   - SUBPARTITION_METHOD
    #   - PARTITION_EXPRESSION
    #   - SUBPARTITION_EXPRESSION
    #   - PARTITION_DESCRIPTION
    #   - TABLE_ROWS
    #   - AVG_ROW_LENGTH
    #   - DATA_LENGTH
    #   - MAX_DATA_LENGTH
    #   - INDEX_LENGTH
    #   - DATA_FREE
    #   - CREATE_TIME
    #   - UPDATE_TIME
    #   - CHECK_TIME
    #   - CHECKSUM
    #   - PARTITION_COMMENT
    #   - NODEGROUP
    #   - TABLESPACE_NAME
    def self.partition_info
      compress_lines(<<-SQL)
        SELECT  *
        FROM information_schema.PARTITIONS
        WHERE TABLE_SCHEMA = ?
        AND TABLE_NAME = ?
      SQL
    end

    def self.drop_partitions(table_name, partition_names)
      return nil if partition_names.empty?

      compress_lines(<<-SQL)
        ALTER TABLE #{table_name}
        DROP PARTITION #{partition_names.join(',')}
      SQL
    end

    def self.create_partition(table_name, partition_name, until_timestamp)
      compress_lines(<<-SQL)
        ALTER TABLE #{table_name}
        ADD PARTITION
        (PARTITION #{partition_name}
         VALUES LESS THAN (#{until_timestamp}))
      SQL
    end

    def self.reorg_partitions(table_name, new_partition_data, reorg_partition_name)
      return nil if new_partition_data.empty?

      partition_suq_query = sort_partition_data(new_partition_data).map do |partition_name, until_timestamp|
        "PARTITION #{partition_name} VALUES LESS THAN (#{until_timestamp})"
      end.join(',')

      compress_lines(<<-SQL)
        ALTER TABLE #{table_name}
        REORGANIZE PARTITION #{reorg_partition_name} INTO
        (#{partition_suq_query})
      SQL
    end

    def self.initialize_partitioning(table_name, partition_data)
      partition_sub_query = sort_partition_data(partition_data).map do |partition_name, until_timestamp|
        "PARTITION #{partition_name} VALUES LESS THAN (#{until_timestamp})"
      end.join(',')

      compress_lines(<<-SQL)
        ALTER TABLE #{table_name}
        PARTITION BY RANGE(timestamp)
        (#{partition_sub_query})
      SQL
    end


    # @param [Hash<String,Fixnum>] partition_data hash of name to timestamp
    # @return [Array] array of partitions sorted by timestamp ascending, with the 'future' partition at the end
    def self.sort_partition_data(partition_data)
      partition_data.to_a.sort do |x,y|
        if x[1] == "MAXVALUE"
          1
        elsif y[1] == "MAXVALUE"
          -1
        else
          x[1] <=> y[1]
        end
      end
    end

    # Replace sequences of whitespace (including newlines) with either
    # a single space or remove them entirely (according to param _spaced_).
    #
    # Copied from:
    #   https://github.com/datamapper/dm-core/blob/master/lib/dm-core/support/ext/string.rb
    #
    #   compress_lines(<<QUERY)
    #     SELECT name
    #     FROM users
    #   QUERY => "SELECT name FROM users"
    #
    # @param [String] string
    #   The input string.
    #
    # @param [TrueClass, FalseClass] spaced (default=true)
    #   Determines whether returned string has whitespace collapsed or removed.
    #
    # @return [String] The input string with whitespace (including newlines) replaced.
    #
    def self.compress_lines(string, spaced = true)
      string.split($/).map { |line| line.strip }.join(spaced ? ' ' : '')
    end

  end
end
