# -*- coding: utf-8 -*-

import logging


def setup_logger(logfile):
    '''
    Setup logging infrastructure

    Reference Source: https://realpython.com/python-logging/
    '''
    logger = logging.getLogger() # root logger

    if logfile:
        # Create handlers
        # All messages goes to a log file
        i_handler = logging.FileHandler(logfile)
        i_handler.setLevel(logging.INFO)

        # Create formatters and add it to handlers
        format = '%(asctime)s - %(levelname)s - %(message)s'
        formatter = logging.Formatter(format)
        i_handler.setFormatter(formatter)

        # Add handlers to the logger
        logger.addHandler(i_handler)